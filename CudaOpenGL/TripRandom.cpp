#include "TripRandom.h"

std::uniform_int_distribution<std::mt19937::result_type> TripRandom::s_Distribution;
std::mt19937 TripRandom::s_re;
bool TripRandom::s_Initialed = false;