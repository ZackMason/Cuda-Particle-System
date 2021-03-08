#pragma once

#include <glad/glad.h>
#include <glm/glm.hpp>

#include <string>

#include "Types.h"

class ComputeShader
{
public:
	ComputeShader();
	~ComputeShader();
	ComputeShader(const std::string& file);

	void Bind(u64 count,
		u32 pos,
		u32 vel,
		u32 time, f32 dt);

	std::string LoadShader(const std::string& fileName);

	unsigned int m_PosTex;
	unsigned int m_VelTex;
	unsigned int m_StatsTex;

	int m_Program;
	int m_shader;
};

