#include "FileSystemUtil.h"
#include "hex.h"
#include "md5.h"
#include "FPLog.h"
#include "Setting.h"
#include "RTMMidGenerator.h"
#include "QuestProcessor.h"

QuestProcessor::QuestProcessor()
{
	registerMethod("userLogin", &QuestProcessor::userLogin);
	registerMethod("userRegister", &QuestProcessor::userRegister);
	registerMethod("createGroup", &QuestProcessor::createGroup);
	registerMethod("joinGroup", &QuestProcessor::joinGroup);
	registerMethod("dropGroup", &QuestProcessor::dropGroup);
	registerMethod("createRoom", &QuestProcessor::createRoom);
	registerMethod("dropRoom", &QuestProcessor::dropRoom);
	registerMethod("lookup", &QuestProcessor::lookup);

	std::string endpoint = Setting::getString("RTM.config.endpoint");
	_rtmServerClient = TCPClient::createClient(endpoint);
	_rtmServerClient->keepAlive();
	_rtmServerClient->setQuestTimeout(10);

	_secret = Setting::getString("RTM.config.secret");
	_pid = Setting::getInt("RTM.config.pid");

	RTMMidGenerator::init();
}

void QuestProcessor::start()
{
	std::string userFile = Setting::getString("IMDemoServer.Store.path");
	std::string userData;
	FileSystemUtil::readFileContent(userFile, userData);
	if (userData.size() > 0)
		_root = Json::parse(userData.c_str());
		
	if (!_root)
	{
		_root.reset(new Json());
		(*_root)["nextUid"] = 1;
		(*_root)["nextGid"] = 1;
		(*_root)["nextRid"] = 1;
	}
}

void QuestProcessor::serverStopped()
{
	std::string userData = _root->str();
	std::string userFile = Setting::getString("BizServer.Store.path");
	FileSystemUtil::saveFileContent(userFile, userData);
}

void QuestProcessor::makeSignAndSalt(int32_t ts, const std::string& cmd, std::string& sign, int64_t& salt)
{
    salt = RTMMidGenerator::genMid();
    std::string content = std::to_string(_pid) + ":" + _secret + ":" + std::to_string(salt) + ":" + cmd + ":" + std::to_string(ts);
    
    unsigned char digest[16];
	md5_checksum(digest, content.c_str(), content.size());
	char hexstr[32 + 1];
	Hexlify(hexstr, digest, sizeof(digest));

    sign.assign(hexstr); 
}

FPQuestPtr QuestProcessor::genTokenQuest(int64_t uid)
{
    int32_t ts = slack_real_sec();
    std::string sign;
    int64_t salt;
    makeSignAndSalt(ts, "gettoken", sign, salt);

    FPQWriter qw(5, "gettoken");
    qw.param("pid", _pid);
    qw.param("sign", sign);
    qw.param("salt", salt);
    qw.param("ts", ts);
    qw.param("uid", uid);
    return qw.take();
}

void QuestProcessor::getToken(int64_t uid, std::shared_ptr<IAsyncAnswer> async)
{
	int pid = _pid;
	FPQuestPtr tokenQuest = genTokenQuest(uid);
	bool launchAsync = _rtmServerClient->sendQuest(tokenQuest, [uid, pid, async](FPAnswerPtr answer, int errorCode){

		if (errorCode == FPNN_EC_OK)
		{
			FPAReader ar(answer);
			FPAWriter aw(3, async->getQuest());
			aw.param("pid", pid);
			aw.param("uid", uid);
			aw.param("token", ar.getString("token"));

			async->sendAnswer(aw.take());
		}
		else
			async->sendErrorAnswer(errorCode, "BizServer error.");
	});

	if (launchAsync == false)
		async->sendErrorAnswer(FPNN_EC_CORE_UNKNOWN_ERROR, "BizServer error. You can retry.");
}

FPAnswerPtr QuestProcessor::userLogin(const FPReaderPtr args, const FPQuestPtr quest, const ConnectionInfo& ci)
{
	/*
		=> userLogin { username:%s, pwd:%s }
		<= { pid:%d, uid:%d, token:%s }
	*/

	std::string username, password;
	if (quest->isHTTP())
	{
		//-- HTTP/HTTPS GET 访问
		username = quest->http_uri("username");
		password = quest->http_uri("pwd");

		//-- 如果是 POST 访问，而不是 GET 访问
		if (username.empty())
			username = args->wantString("username");

		if (password.empty())
			password = args->wantString("pwd");
	}
	else
	{
		//-- FPNN/WebSocket/HTTP POST/HTTPS POST 访问
		username = args->wantString("username");
		password = args->wantString("pwd");
	}

	int64_t uid = 0;
	bool passwordMached = true;
	{
		std::unique_lock<std::mutex> lck(_mutex);
		if ((*_root)["account"].exist(username))
		{
			if ((std::string)((*_root)["account"][username]["pwd"]) == password)
				uid = (*_root)["account"][username]["uid"];
			else
				passwordMached = false;
		}
	}

	if (passwordMached == false)
		return FpnnErrorAnswer(quest, FPNN_EC_CORE_UNKNOWN_ERROR, "Password is wrong!");

	if (uid == 0)
		return FpnnErrorAnswer(quest, FPNN_EC_CORE_UNKNOWN_ERROR, "User is unregistered!");

	getToken(uid, genAsyncAnswer(quest));

	return nullptr;
}

FPAnswerPtr QuestProcessor::userRegister(const FPReaderPtr args, const FPQuestPtr quest, const ConnectionInfo& ci)
{
	/*
		=> userRegister { username:%s, pwd:%s }
		<= { pid:%d, uid:%d, token:%s }
	*/

	std::string username, password;
	if (quest->isHTTP())
	{
		//-- HTTP/HTTPS GET 访问
		username = quest->http_uri("username");
		password = quest->http_uri("pwd");

		//-- 如果是 POST 访问，而不是 GET 访问
		if (username.empty())
			username = args->wantString("username");

		if (password.empty())
			password = args->wantString("pwd");
	}
	else
	{
		//-- FPNN/WebSocket/HTTP POST/HTTPS POST 访问
		username = args->wantString("username");
		password = args->wantString("pwd");
	}

	int64_t uid = 0;
	{
		std::unique_lock<std::mutex> lck(_mutex);
		if ((*_root)["account"].exist(username) == false)
		{
			(*_root)["account"][username]["pwd"] = password;

			uid = (*_root)["nextUid"];

			(*_root)["nextUid"] = uid + 1;
			(*_root)["account"][username]["uid"] = uid;
		}
	}

	if (uid == 0)
		return FpnnErrorAnswer(quest, FPNN_EC_CORE_UNKNOWN_ERROR, "Username is existed!");

	getToken(uid, genAsyncAnswer(quest));

	return nullptr;
}

void QuestProcessor::sendAsyncQuest(FPQuestPtr quest, std::shared_ptr<IAsyncAnswer> async, FPAnswerPtr realAnswer)
{
	bool launchAsync = _rtmServerClient->sendQuest(quest, [async, realAnswer](FPAnswerPtr answer, int errorCode){

		if (errorCode == FPNN_EC_OK)
		{
			if (realAnswer)
				async->sendAnswer(realAnswer);
			else
				async->sendEmptyAnswer();
		}
		else
			async->sendErrorAnswer(errorCode, "BizServer error.");
	});

	if (launchAsync == false)
		async->sendErrorAnswer(FPNN_EC_CORE_UNKNOWN_ERROR, "BizServer error. You can retry.");
}

FPAnswerPtr QuestProcessor::extraParams(const FPReaderPtr args, const FPQuestPtr quest,
			const char* xidKey, const char* xnameKey, int64_t &xid, std::string& xname)
{
	if (quest->isHTTP())
	{
		//-- HTTP/HTTPS GET 访问
		std::string xidString = quest->http_uri(xidKey);
		if (xidString.empty())
			xid = 0;
		else
			xid = std::stoll(xidString);

		xname = quest->http_uri(xnameKey);

		//-- 如果是 POST 访问，而不是 GET 访问
		if (xid == 0)
			xid = args->wantInt(xidKey);

		if (xname.empty())
			xname = args->wantString(xnameKey);
	}
	else
	{
		//-- FPNN/WebSocket/HTTP POST/HTTPS POST 访问
		xid = args->wantInt(xidKey);
		xname = args->wantString(xnameKey);
	}

	if (xid == 0)
		return FpnnErrorAnswer(quest, FPNN_EC_CORE_UNKNOWN_ERROR, std::string("Invalid ").append(xidKey).append("!").c_str());

	if (xname.empty())
		return FpnnErrorAnswer(quest, FPNN_EC_CORE_UNKNOWN_ERROR, std::string("Invalid ").append(xnameKey).append("!").c_str());

	return nullptr;
}

FPAnswerPtr QuestProcessor::createGroup(const FPReaderPtr args, const FPQuestPtr quest, const ConnectionInfo& ci)
{
	/*
		=> createGroup { uid:%d, group:%s }
		<= { gid:%d }
	*/

	int64_t uid = 0;
	std::string groupname;

	FPAnswerPtr answer = extraParams(args, quest, "uid", "group", uid, groupname);
	if (answer)
		return answer;

	int64_t gid = 0;

	{
		std::unique_lock<std::mutex> lck(_mutex);
		if ((*_root)["group"].exist(groupname) == false)
		{
			gid = (*_root)["nextGid"];

			(*_root)["nextGid"] = gid + 1;
			(*_root)["group"][groupname] = gid;
		}
	}

	if (gid == 0)
		return FpnnErrorAnswer(quest, FPNN_EC_CORE_UNKNOWN_ERROR, "Group is existed!");

	int32_t ts = slack_real_sec();
    std::string sign;
    int64_t salt;
    makeSignAndSalt(ts, "addgroupmembers", sign, salt);

    FPQWriter qw(6, "addgroupmembers");
    qw.param("pid", _pid);
    qw.param("sign", sign);
    qw.param("salt", salt);
    qw.param("ts", ts);
    qw.param("gid", gid);
    qw.param("uids", std::set<int64_t>{uid});

    FPAWriter aw(1, quest);
    aw.param("gid", gid);

    sendAsyncQuest(qw.take(), genAsyncAnswer(quest), aw.take());

	return nullptr;
}

FPAnswerPtr QuestProcessor::joinGroup(const FPReaderPtr args, const FPQuestPtr quest, const ConnectionInfo& ci)
{
	/*
		=> joinGroup { uid:%d, group:%s }
		<= { gid:%d }
	*/

	int64_t uid = 0;
	std::string groupname;

	FPAnswerPtr answer = extraParams(args, quest, "uid", "group", uid, groupname);
	if (answer)
		return answer;

	int64_t gid = 0;

	{
		std::unique_lock<std::mutex> lck(_mutex);
		if ((*_root)["group"].exist(groupname))
			gid = (*_root)["group"][groupname];
		else
			return FpnnErrorAnswer(quest, FPNN_EC_CORE_UNKNOWN_ERROR, "Group is not existed!");		
	}

	int32_t ts = slack_real_sec();
    std::string sign;
    int64_t salt;
    makeSignAndSalt(ts, "addgroupmembers", sign, salt);

    FPQWriter qw(6, "addgroupmembers");
    qw.param("pid", _pid);
    qw.param("sign", sign);
    qw.param("salt", salt);
    qw.param("ts", ts);
    qw.param("gid", gid);
    qw.param("uids", std::set<int64_t>{uid});

    FPAWriter aw(1, quest);
    aw.param("gid", gid);

    sendAsyncQuest(qw.take(), genAsyncAnswer(quest), aw.take());

	return nullptr;
}

FPAnswerPtr QuestProcessor::dropGroup(const FPReaderPtr args, const FPQuestPtr quest, const ConnectionInfo& ci)
{
	/*
		=> dropGroup { group:%s, gid:%d }
		<= {}
	*/

	int64_t gid = 0;
	std::string groupname;

	FPAnswerPtr answer = extraParams(args, quest, "gid", "group", gid, groupname);
	if (answer)
		return answer;

	bool exist = true;
	bool matched = true;

	{
		std::unique_lock<std::mutex> lck(_mutex);
		if ((*_root)["group"].exist(groupname) == false)
			exist = false;
		else if ((int64_t)((*_root)["group"][groupname]) != gid)
			matched = false;
		else
			(*_root)["group"].remove(groupname);
	}

	if (!exist)
		return FPAWriter::emptyAnswer(quest);

	if (!matched)
		return FpnnErrorAnswer(quest, FPNN_EC_CORE_UNKNOWN_ERROR, "Group is mismatched!");

	int32_t ts = slack_real_sec();
    std::string sign;
    int64_t salt;
    makeSignAndSalt(ts, "delgroup", sign, salt);

    FPQWriter qw(5, "delgroup");
    qw.param("pid", _pid);
    qw.param("sign", sign);
    qw.param("salt", salt);
    qw.param("ts", ts);
    qw.param("gid", gid);

    FPAWriter aw(1, quest);
    aw.param("gid", gid);

    sendAsyncQuest(qw.take(), genAsyncAnswer(quest));

	return nullptr;
}

FPAnswerPtr QuestProcessor::createRoom(const FPReaderPtr args, const FPQuestPtr quest, const ConnectionInfo& ci)
{
	/*
		=> createRoom { room:%s }
		<= { rid:%d }
	*/

	std::string roomname;

	if (quest->isHTTP())
	{
		//-- HTTP/HTTPS GET 访问
		roomname = quest->http_uri("room");

		//-- 如果是 POST 访问，而不是 GET 访问
		if (roomname.empty())
			roomname = args->wantString("room");
	}
	else
	{
		//-- FPNN/WebSocket/HTTP POST/HTTPS POST 访问
		roomname = args->wantString("room");
	}

	int64_t rid = 0;

	{
		std::unique_lock<std::mutex> lck(_mutex);
		if ((*_root)["room"].exist(roomname) == false)
		{
			rid = (*_root)["nextRid"];

			(*_root)["nextRid"] = rid + 1;
			(*_root)["room"][roomname] = rid;
		}
		else
			rid = (*_root)["room"][roomname];
	}

    FPAWriter aw(1, quest);
    aw.param("rid", rid);

	return aw.take();
}

FPAnswerPtr QuestProcessor::dropRoom(const FPReaderPtr args, const FPQuestPtr quest, const ConnectionInfo& ci)
{
	/*
		=> dropRoom { room:%s, rid:%d }
		<= {}
	*/

	int64_t rid = 0;
	std::string roomname;

	FPAnswerPtr answer = extraParams(args, quest, "rid", "room", rid, roomname);
	if (answer)
		return answer;

	bool exist = true;
	bool matched = true;

	{
		std::unique_lock<std::mutex> lck(_mutex);
		if ((*_root)["room"].exist(roomname) == false)
			exist = false;
		else if ((int64_t)((*_root)["room"][roomname]) != rid)
			matched = false;
		else
			(*_root)["room"].remove(roomname);
	}

	if (!exist)
		return FPAWriter::emptyAnswer(quest);

	if (!matched)
		return FpnnErrorAnswer(quest, FPNN_EC_CORE_UNKNOWN_ERROR, "Room is mismatched!");

	return FPAWriter::emptyAnswer(quest);
}

FPAnswerPtr QuestProcessor::lookup(const FPReaderPtr args, const FPQuestPtr quest, const ConnectionInfo& ci)
{
	/*
		=> lookup { ?users:[%s], ?groups:[%s], ?rooms:[%s], ?uids:[%d], ?gids:[%d], ?rids:[%d] }
		<= { ?users:{%s:%d}, ?groups:{%s:%d}, ?rooms:{%s:%d} }
		Only POST or FPNN protocol accessing.
	*/

	std::set<int64_t> uids, gids, rids;
	std::set<std::string> users, groups, rooms;

	uids = args->get("uids", uids);
	gids = args->get("gids", gids);
	rids = args->get("rids", rids);

	users = args->get("users", users);
	groups = args->get("groups", groups);
	rooms = args->get("rooms", rooms);

	std::map<std::string, int64_t> userResult, groupResult, roomResult;

	//====================================//
	{
		std::unique_lock<std::mutex> lck(_mutex);

		for (auto& username: users)
		{
			if ((*_root)["account"].exist(username))
				userResult[username] = (*_root)["account"][username]["uid"];
		}

		for (auto& groupname: groups)
		{
			if ((*_root)["group"].exist(groupname))
				groupResult[groupname] = (*_root)["group"][groupname];
		}

		for (auto& roomname: rooms)
		{
			if ((*_root)["room"].exist(roomname))
				roomResult[roomname] = (*_root)["room"][roomname];
		}

		if (uids.size() > 0)
		{
			const std::map<std::string, JsonPtr> * accountDict = _root->getDict("account");
			for (auto& node: *accountDict)
			{
				int64_t uid = (int64_t)(node.second->wantInt("uid"));
				if (uids.find(uid) != uids.end())
				{
					userResult[node.first] = uid;
					uids.erase(uid);

					if (uids.empty())
						break;
				}
			}
		}
			
		if (gids.size() > 0)
		{
			const std::map<std::string, JsonPtr> * groupDict = _root->getDict("group");
			for (auto& node: *groupDict)
			{
				int64_t gid = *(node.second);
				if (gids.find(gid) != gids.end())
				{
					groupResult[node.first] = gid;
					gids.erase(gid);

					if (gids.empty())
						break;
				}
			}
		}

		if (rids.size() > 0)
		{
			const std::map<std::string, JsonPtr> * roomDict = _root->getDict("room");
			for (auto& node: *roomDict)
			{
				int64_t rid = *(node.second);
				if (rids.find(rid) != rids.end())
				{
					roomResult[node.first] = rid;
					rids.erase(rid);

					if (rids.empty())
						break;
				}
			}
		}
	}
	//====================================//

	FPAWriter aw(3, quest);
    aw.param("users", userResult);
    aw.param("groups", groupResult);
    aw.param("rooms", roomResult);

	return aw.take();
}