#version 330 core

layout (location = 0) in vec3 aPos;

uniform mat4 uP;
uniform mat4 uV;

void main()
{
	gl_Position = uP * uV * vec4(aPos.x, aPos.y, aPos.z, 1.0);
}