#include "ComputeShader.h"
#include <glad/glad.h>

#include <iostream>
#include <string>
#include <fstream>
#include <sstream>
#include <stdio.h>

ComputeShader::ComputeShader(const std::string& file)
{
	int work_grp_cnt[3];

	glGetIntegeri_v(GL_MAX_COMPUTE_WORK_GROUP_COUNT, 0, &work_grp_cnt[0]);
	glGetIntegeri_v(GL_MAX_COMPUTE_WORK_GROUP_COUNT, 1, &work_grp_cnt[1]);
	glGetIntegeri_v(GL_MAX_COMPUTE_WORK_GROUP_COUNT, 2, &work_grp_cnt[2]);

	printf("max global (total) work group size x:%i y:%i z:%i\n",
		work_grp_cnt[0], work_grp_cnt[1], work_grp_cnt[2]);

	int work_grp_size[3];

	glGetIntegeri_v(GL_MAX_COMPUTE_WORK_GROUP_SIZE, 0, &work_grp_size[0]);
	glGetIntegeri_v(GL_MAX_COMPUTE_WORK_GROUP_SIZE, 1, &work_grp_size[1]);
	glGetIntegeri_v(GL_MAX_COMPUTE_WORK_GROUP_SIZE, 2, &work_grp_size[2]);

	printf("max local (in one shader) work group sizes x:%i y:%i z:%i\n",
		work_grp_size[0], work_grp_size[1], work_grp_size[2]);

	std::string code;
	std::ifstream shaderFile;

	shaderFile.exceptions(std::ifstream::failbit | std::ifstream::badbit);
	
	std::string path = "./res/" + file + ".cs";

	try
	{
		// open 
		shaderFile.open(path);
		std::stringstream shaderStream;
		// read file's buffer contents into streams
		shaderStream << shaderFile.rdbuf();
		// close file handlers
		shaderFile.close();
		// convert stream into string
		code = shaderStream.str();
	}
	catch (std::ifstream::failure e)
	{
		printf("ERROR::SHADER::FILE_NOT_SUCCESFULLY_READ: %s", file.c_str());
	}
	const char* shaderCode = code.c_str();

	int shader = glCreateShader(GL_COMPUTE_SHADER);
	glShaderSource(shader, 1, &shaderCode, NULL);
	glCompileShader(shader);
	// check for shader compile errors
	int success;
	char infoLog[512];
	glGetShaderiv(shader, GL_COMPILE_STATUS, &success);
	if (!success)
	{
		glGetShaderInfoLog(shader, 512, NULL, infoLog);
		printf("ERROR::SHADER::%s::VERTEX::COMPILATION_FAILED: %s", file.c_str(), infoLog);
	}
	m_Program = glCreateProgram();
	glAttachShader(m_Program, shader);
	glLinkProgram(m_Program);
	glGetProgramiv(m_Program, GL_LINK_STATUS, &success);
	if (!success) {
		glGetProgramInfoLog(m_Program, 512, NULL, infoLog);
		printf("ERROR::SHADER::%s::PROGRAM::LINKING_FAILED: %s", file, infoLog);
	}
	else
	{
		printf("LOADED SHADER: %s", file);
	}
	m_shader = shader;

	glDeleteShader(shader);


}

void ComputeShader::Bind(u64 count, 
                         u32 pos,
                         u32 vel,
                         u32 time,
                         f32 dt)
{
	glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 0, pos);
	glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 1, vel);
	glBindBufferBase(GL_SHADER_STORAGE_BUFFER, 2, time);
	
	glUseProgram(m_Program);
	glUniform1f(glGetUniformLocation(m_Program, "dt"), dt);
	glDispatchCompute(100, 100, 1);
	glMemoryBarrier(GL_ALL_BARRIER_BITS);
}

ComputeShader::~ComputeShader()
{
	glDetachShader(m_Program, m_shader);
	glDeleteProgram(m_Program);
}
