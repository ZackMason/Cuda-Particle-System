#pragma once
#include <string>
#include "Types.h"
#include <glad/glad.h>


struct Texture
{
	u32 m_ID;

	i32 m_Width;
	i32 m_Height;
	i32 m_Channels;
	GLenum m_Format;

	void Bind(u32 unit) const;
	
	Texture() = default;
	~Texture();
	Texture(const std::string&);
};

