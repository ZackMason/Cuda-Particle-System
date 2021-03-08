#pragma once
#include <string>

#include "Types.h"
#include <glad/glad.h>
#include <unordered_map>

struct Shader
{
	i32 m_ID;
	i32 m_FragmentShader;
	i32 m_VertexShader;
	i32 m_GeoShader = 0;
	mutable std::unordered_map<std::string, i32> m_uniform_location_cache;

	i32 GetUniformLocation(const std::string& name) const;

	void setUniformBlock(const std::string &name, int loc) const;
	
	void setBool (const  std::string &name, bool value) const;
	void setInt  (const  std::string &name, i32  value) const;
	void setFloat(const  std::string &name, f32  value) const;
	void setVec2 (const  std::string &name, f32 x, f32 y) const;
	void setVec3 (const  std::string &name, f32 x, f32 y, f32 z) const;
	void setVec4 (const  std::string &name, f32 x, f32 y, f32 z, float w);
	void setVec2 (const  std::string &name, const v2 &value) const;
	void setVec3 (const  std::string &name, const v3 &value) const;
	void setVec4 (const  std::string &name, const v4 &value) const;
	void setMat2 (const  std::string &name, const m2 &mat) const;
	void setMat3 (const  std::string &name, const m3 &mat) const;
	void setMat4 (const  std::string &name, const m4 &mat) const;

	operator i32() const { return m_ID; }
	void Bind() const;
	
	Shader(const std::string& file, bool geo = false);
	~Shader();
};

