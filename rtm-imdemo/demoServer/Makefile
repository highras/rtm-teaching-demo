EXES_SERVER = IMDemoServer

FPNN_DIR = ../../../fpnn
CFLAGS +=
CXXFLAGS +=
CPPFLAGS += -I$(FPNN_DIR)/extends -I$(FPNN_DIR)/core -I$(FPNN_DIR)/proto -I$(FPNN_DIR)/base -I$(FPNN_DIR)/proto/msgpack -I$(FPNN_DIR)/proto/rapidjson
LIBS += -L$(FPNN_DIR)/core -L$(FPNN_DIR)/proto -L$(FPNN_DIR)/extends -L$(FPNN_DIR)/base -lfpnn

OBJS_SERVER = IMDemoServer.o RTMMidGenerator.o QuestProcessor.o

all: $(EXES_SERVER)

clean:
	$(RM) *.o $(EXES_SERVER)
include $(FPNN_DIR)/def.mk
