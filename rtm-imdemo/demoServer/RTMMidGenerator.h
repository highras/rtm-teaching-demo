#ifndef RTM_MID_GENERATOR_H
#define RTM_MID_GENERATOR_H
#include <mutex>

class RTMMidGenerator{
    public:
		static void init();
        static int64_t getNextMillis(int64_t lastTime);
        static int64_t genMid();
    private:
		static int32_t _count;
        static int32_t _randId;
        static int32_t _randBits;
        static int32_t _sequenceBits;
        static int32_t _sequenceMask;
        static int64_t _lastTime;
        static std::mutex _mutex;
};
#endif