#include "RTMMidGenerator.h"
#include <random>
#include "msec.h"

int32_t RTMMidGenerator::_count = 0;
int32_t RTMMidGenerator::_randId = 0;
int32_t RTMMidGenerator::_randBits = 8;
int32_t RTMMidGenerator::_sequenceBits = 6;
int32_t RTMMidGenerator::_sequenceMask = 0;
int64_t RTMMidGenerator::_lastTime = 0;
std::mutex RTMMidGenerator::_mutex;

void RTMMidGenerator::init()
{
    _randId = rand() % 255 + 1;
    _sequenceMask = -1 ^ (-1 << _sequenceBits);
}

int64_t RTMMidGenerator::getNextMillis(int64_t lastTime)
{
    int64_t time = slack_real_sec();
    while (time < lastTime)
        time = slack_real_sec();
    return time;
}

int64_t RTMMidGenerator::genMid()
{
    std::lock_guard<std::mutex> lck(_mutex);
    int64_t time = slack_real_sec();
    _count = (_count + 1) & _sequenceMask;
    if (_count == 0)
        time = getNextMillis(_lastTime);
    _lastTime = time;
    return (time << (_randBits + _sequenceBits)) | (uint32_t)(_randId << _sequenceBits) | (uint32_t)_count;
}