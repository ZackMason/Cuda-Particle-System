#pragma once
#include <random>

class TripRandom
{
public:
	TripRandom() = default;
	~TripRandom() = default;

	static void Init()
	{
		s_re.seed(std::random_device()());
		s_Initialed = true;
	}

	operator float() const
	{
		return Float();
	}
	
	static float Float()
	{
		if (!s_Initialed) Init();
		return static_cast<float>(s_Distribution(s_re)) / static_cast<float>(std::numeric_limits<uint32_t>::max());
	}

	static float FloatWithNeg()
	{
		if (!s_Initialed) Init();
		return Float() * 2.0f - 1.0f;
	}
	
	static bool s_Initialed;
	static std::mt19937 s_re;
	static std::uniform_int_distribution<std::mt19937::result_type> s_Distribution;
};

