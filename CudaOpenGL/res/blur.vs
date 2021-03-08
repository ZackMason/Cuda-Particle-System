#version 330 core
layout(location=0)in vec3 aPos;
layout(location=1)in vec2 aUV;
//layout(location=1)in vec3 aNormal;

out vec2 voUV;

void main()
{
    voUV=aUV;
    gl_Position=vec4(aPos.x,aPos.y,.0,1.);
}