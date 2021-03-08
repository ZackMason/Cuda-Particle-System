#version 330 core

layout (location = 0) in vec3 aPos;
layout (location = 1) in vec3 aCol;

uniform mat4 uP;
uniform mat4 uV;

out VS_OUT {
    vec3 color;
} vs_out;

void main()
{
	vs_out.color = aCol;
	gl_Position = uP * uV * vec4(aPos.x, aPos.y, aPos.z, 1.0);
}