#include "Texture.h"

#define STB_IMAGE_IMPLEMENTATION
#include "stb_image.h"

Texture::~Texture()
{
	glDeleteTextures(1, &m_ID);
}

Texture::Texture(const std::string& file)
{
	stbi_set_flip_vertically_on_load(true);

	glGenTextures(1, &m_ID);
	glBindTexture(GL_TEXTURE_2D, m_ID);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST_MIPMAP_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST_MIPMAP_NEAREST);

	const std::string path = "./res/TEXTURES/" + file;

	unsigned char *data = stbi_load(path.c_str(), &m_Width, &m_Height, &m_Channels, 0);

	if (data)
	{
		if (m_Channels == 3)
			glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, m_Width, m_Height, 0, GL_RGB, GL_UNSIGNED_BYTE, data);
		else if (m_Channels == 4)
			glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, m_Width, m_Height, 0, GL_RGBA, GL_UNSIGNED_BYTE, data);
		glGenerateMipmap(GL_TEXTURE_2D);
		//printf("Loaded Texture: %s\n", file);
		stbi_image_free(data);
	}
	else
	{
		printf("Failed to Load Texture: %s\n", file);
	}
}

void Texture::Bind(u32 unit) const
{
	assert(unit >= 0 && unit < 32);
	glActiveTexture(GL_TEXTURE0 + unit);
	glBindTexture(GL_TEXTURE_2D, m_ID);
}
