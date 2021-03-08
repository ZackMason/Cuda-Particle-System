#version 330 core

layout (location = 0) out vec4 FragColor;
layout (location = 1) out vec4 BrightColor;

in vec3 oColor;

in GS_OUT
{
    vec3 Pos;
    vec2 UV;
} gs_in;

void main()
{
	if (dot(gs_in.UV-.5,gs_in.UV-.5) > .25)
       discard;

	FragColor = vec4(pow(oColor,vec3(2.2)),1.0) * 10.;
	float brightness = dot(FragColor.rgb, vec3(0.2126, 0.7152, 0.0722));
    BrightColor = FragColor * brightness;
    #if 0
    if(brightness > 1.0)
        BrightColor = vec4(FragColor.rgb, 1.0);
    else
        BrightColor = vec4(0.0, 0.0, 0.0, 1.0);
    #endif
	//vec4(1.0, 0.0, 0.0, 1.0);
}