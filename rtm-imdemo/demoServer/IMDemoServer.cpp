#include <iostream>
#include "TCPEpollServer.h"
#include "QuestProcessor.h"
#include "Setting.h"

using namespace fpnn;

int main(int argc, char* argv[])
{
	if (argc != 2)
	{
		std::cout<<"Usage: "<<argv[0]<<" config"<<std::endl;
		return 0;
	}
	if(!Setting::load(argv[1])){
		std::cout<<"Config file error:"<< argv[1]<<std::endl;
		return 1;
	}

	ServerPtr server = TCPEpollServer::create();
	server->setQuestProcessor(std::make_shared<QuestProcessor>());
	if (server->startup())
		server->run();

	return 0;
}
