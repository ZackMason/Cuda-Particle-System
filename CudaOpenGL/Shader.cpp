#include <regex>
#include <sstream>
#include <fstream>
#include <iostream>

#include <glad/glad.h>
#include <stdio.h>

#include "Shader.h"
#include "Types.h"

const std::regex r("(#include <)([a-zA-Z]+)(\.slib>)");

void IncludePreprocess(std::string& code)
{
	std::smatch m;
	while (std::regex_search(code, m, r))
	{
		std::ifstream file;
		std::stringstream code_stream;
		file.open("./res/" + static_cast<std::string>(m[2]) + ".slib");
		if (file.is_open())
		{
			code_stream << file.rdbuf();
			file.close();
			std::regex file_reg("(#include <)" + static_cast<std::string>(m[2]) + "(\.slib>)");
			code = std::regex_replace(code, file_reg, code_stream.str());
		}
		else
			printf("TRIP SHADER INCLUDE ERROR: file \"%s\" not found", static_cast<std::string>(m[2]).c_str());
	}
}

Shader::Shader(const std::string& file, bool geo)
{
	std::string vertexCode;
	std::string fragmentCode;
	std::string geoCode;
	std::ifstream vShaderFile;
	std::ifstream fShaderFile;
	std::ifstream gShaderFile;
	// ensure ifstream objects can throw exceptions:
	vShaderFile.exceptions(std::ifstream::failbit | std::ifstream::badbit);
	fShaderFile.exceptions(std::ifstream::failbit | std::ifstream::badbit);
	gShaderFile.exceptions(std::ifstream::failbit | std::ifstream::badbit);

	std::string vertexPath = "./res/" + file + ".vs";
	std::string fragmentPath = "./res/" + file + ".fs";
	std::string geoPath = "./res/" + file + ".gs";
	try
	{
		// open 
		vShaderFile.open(vertexPath);
		fShaderFile.open(fragmentPath);
		std::stringstream vShaderStream, fShaderStream, gShaderStream;
		// read file's buffer contents into streams
		vShaderStream << vShaderFile.rdbuf();
		fShaderStream << fShaderFile.rdbuf();
		// close file handlers
		vShaderFile.close();
		fShaderFile.close();
		// convert stream into string
		vertexCode = vShaderStream.str();
		fragmentCode = fShaderStream.str();

		if(geo)
		{
			gShaderFile.open(geoPath);
			gShaderStream << gShaderFile.rdbuf();
			gShaderFile.close();
			geoCode = gShaderStream.str();
			IncludePreprocess(geoCode);
		}

		IncludePreprocess(vertexCode);
		IncludePreprocess(fragmentCode);
	}
	catch (std::ifstream::failure e)
	{
		printf("ERROR::SHADER::FILE_NOT_SUCCESFULLY_READ: %s\n", file.c_str());
	}

	const char* vShaderCode = vertexCode.c_str();
	const char* fShaderCode = fragmentCode.c_str();

	int vertexShader = glCreateShader(GL_VERTEX_SHADER);
	glShaderSource(vertexShader, 1, &vShaderCode, NULL);
	glCompileShader(vertexShader);
	// check for shader compile errors
	int success;
	char infoLog[512];
	glGetShaderiv(vertexShader, GL_COMPILE_STATUS, &success);
	if (!success)
	{
		glGetShaderInfoLog(vertexShader, 512, NULL, infoLog);
		printf("ERROR::SHADER::%s::VERTEX::COMPILATION_FAILED: %s\n", file, infoLog);
	}
	// fragment shader
	int fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
	glShaderSource(fragmentShader, 1, &fShaderCode, NULL);
	glCompileShader(fragmentShader);
	// check for shader compile errors
	glGetShaderiv(fragmentShader, GL_COMPILE_STATUS, &success);
	if (!success)
	{
		glGetShaderInfoLog(fragmentShader, 512, NULL, infoLog);
		printf("ERROR::SHADER::%s::FRAGMENT::COMPILATION_FAILED: %s\n", file, infoLog);
	}

	int geoShader;

	// link shaders
	m_ID = glCreateProgram();
	glAttachShader(m_ID, vertexShader);
	glAttachShader(m_ID, fragmentShader);
	if (geo)
	{
		const char* gShaderCode = geoCode.c_str();
		geoShader = glCreateShader(GL_GEOMETRY_SHADER);
		glShaderSource(geoShader, 1, &gShaderCode, NULL);
		glCompileShader(geoShader);
		// check for shader compile errors
		glGetShaderiv(geoShader, GL_COMPILE_STATUS, &success);
		if (!success)
		{
			glGetShaderInfoLog(geoShader, 512, NULL, infoLog);
			printf("ERROR::SHADER::%s::FRAGMENT::COMPILATION_FAILED: %s\n", file, infoLog);
		}
		glAttachShader(m_ID, geoShader);
		m_GeoShader = geoShader;
	}

	glLinkProgram(m_ID);
	// check for linking errors
	glGetProgramiv(m_ID, GL_LINK_STATUS, &success);
	if (!success) {
		glGetProgramInfoLog(m_ID, 512, NULL, infoLog);
		printf("ERROR::SHADER::%s::PROGRAM::LINKING_FAILED: %s\n", file, infoLog);
	}
	else
	{
		printf("LOADED SHADER: %s\n", file);
	}
	m_FragmentShader = fragmentShader;
	m_VertexShader = vertexShader;
	glDeleteShader(vertexShader);
	glDeleteShader(fragmentShader);
	if (geo)
		glDeleteShader(geoShader);
}

void Shader::Bind() const
{
	glUseProgram(m_ID);
}

GLint Shader::GetUniformLocation(const std::string& name) const
{
	//PROFILE_SCOPE(name.c_str());

	auto itr = m_uniform_location_cache.find(name);
	if (itr != m_uniform_location_cache.end())
		return itr->second;
	i32 location = glGetUniformLocation(m_ID, name.c_str());
	m_uniform_location_cache[name] = location;
	return location;
}

// utility uniform functions
// ------------------------------------------------------------------------
void Shader::setUniformBlock(const std::string& name, int loc) const
{
	auto index = glGetUniformBlockIndex(m_ID, name.c_str());
	if (index != GL_INVALID_INDEX)
		glUniformBlockBinding(m_ID, index, loc);
}

void Shader::setBool(const std::string &name, bool value) const
{
	glUniform1i(GetUniformLocation(name), (int)value);
}
// ------------------------------------------------------------------------
void Shader::setInt(const std::string &name, int value) const
{
	glUniform1i(GetUniformLocation(name), value);
}
// ------------------------------------------------------------------------
void Shader::setFloat(const std::string &name, float value) const
{
	glUniform1f(GetUniformLocation(name), value);
}

// ------------------------------------------------------------------------
void Shader::setVec2(const std::string &name, const glm::vec2 &value) const
{
	glUniform2fv(GetUniformLocation(name), 1, &value[0]);
}
void Shader::setVec2(const std::string &name, float x, float y) const
{
	glUniform2f(GetUniformLocation(name), x, y);
}
// ------------------------------------------------------------------------
void Shader::setVec3(const std::string &name, const glm::vec3 &value) const
{
	glUniform3fv(GetUniformLocation(name), 1, &value[0]);
}
void Shader::setVec3(const std::string &name, float x, float y, float z) const
{
	glUniform3f(GetUniformLocation(name), x, y, z);
}
// ------------------------------------------------------------------------
void Shader::setVec4(const std::string &name, const glm::vec4 &value) const
{
	glUniform4fv(GetUniformLocation(name), 1, &value[0]);
}
void Shader::setVec4(const std::string &name, float x, float y, float z, float w)
{
	glUniform4f(GetUniformLocation(name), x, y, z, w);
}
// ------------------------------------------------------------------------
void Shader::setMat2(const std::string &name, const glm::mat2 &mat) const
{
	glUniformMatrix2fv(GetUniformLocation(name), 1, GL_FALSE, &mat[0][0]);
}
// ------------------------------------------------------------------------
void Shader::setMat3(const std::string &name, const glm::mat3 &mat) const
{
	glUniformMatrix3fv(GetUniformLocation(name), 1, GL_FALSE, &mat[0][0]);
}
// ------------------------------------------------------------------------
void Shader::setMat4(const std::string &name, const glm::mat4 &mat) const
{
	glUniformMatrix4fv(GetUniformLocation(name), 1, GL_FALSE, &mat[0][0]);
}

Shader::~Shader()
{
	glDetachShader(m_ID, m_FragmentShader);
	glDetachShader(m_ID, m_VertexShader);
	glDeleteProgram(m_ID);
}
