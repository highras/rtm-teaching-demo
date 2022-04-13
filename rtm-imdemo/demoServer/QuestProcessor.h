#ifndef QuestProcessor_H
#define QuestProcessor_H

#include "FPJson.h"
#include "TCPClient.h"
#include "IQuestProcessor.h"

using namespace fpnn;

class QuestProcessor: public IQuestProcessor
{
	QuestProcessorClassPrivateFields(QuestProcessor)

	std::mutex _mutex;
	JsonPtr _root;

	int _pid;
	std::string _secret;

	TCPClientPtr _rtmServerClient;

	void makeSignAndSalt(int32_t ts, const std::string& cmd, std::string& sign, int64_t& salt);
	FPQuestPtr genTokenQuest(int64_t uid);
	void getToken(int64_t uid, std::shared_ptr<IAsyncAnswer> async);
	void sendAsyncQuest(FPQuestPtr quest, std::shared_ptr<IAsyncAnswer> async, FPAnswerPtr realAnswer = nullptr);

	FPAnswerPtr extraParams(const FPReaderPtr args, const FPQuestPtr quest, const char* xidKey, const char* xnameKey,
		int64_t &xid, std::string& xname);

public:
	virtual void start();
	virtual void serverStopped();

	FPAnswerPtr userLogin(const FPReaderPtr args, const FPQuestPtr quest, const ConnectionInfo& ci);
	FPAnswerPtr userRegister(const FPReaderPtr args, const FPQuestPtr quest, const ConnectionInfo& ci);
	FPAnswerPtr createGroup(const FPReaderPtr args, const FPQuestPtr quest, const ConnectionInfo& ci);
	FPAnswerPtr joinGroup(const FPReaderPtr args, const FPQuestPtr quest, const ConnectionInfo& ci);
	FPAnswerPtr dropGroup(const FPReaderPtr args, const FPQuestPtr quest, const ConnectionInfo& ci);
	FPAnswerPtr createRoom(const FPReaderPtr args, const FPQuestPtr quest, const ConnectionInfo& ci);
	FPAnswerPtr dropRoom(const FPReaderPtr args, const FPQuestPtr quest, const ConnectionInfo& ci);
	FPAnswerPtr lookup(const FPReaderPtr args, const FPQuestPtr quest, const ConnectionInfo& ci);

	QuestProcessor();
	virtual ~QuestProcessor() {}

	QuestProcessorClassBasicPublicFuncs
};

#endif