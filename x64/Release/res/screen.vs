#version 330 core

layout (location = 0) in vec3 aPos;
layout (location = 1) in vec2 aUV;

out vec2 oUV;

void main()
{
    oUV = aUV;
	gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0);
}