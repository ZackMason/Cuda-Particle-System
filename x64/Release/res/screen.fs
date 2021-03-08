#version 330 core

out vec4 FragColor;

in vec2 oUV;

uniform sampler2D uTexture0;
uniform sampler2D uTexture1;

void main()
{
    vec3 color = texture(uTexture0,oUV).rgb;
    vec3 bloom = texture(uTexture1,oUV).rgb;
    color += bloom;

    color = pow(color, vec3(1.0/2.2));

	FragColor = vec4(color,1.0);
}