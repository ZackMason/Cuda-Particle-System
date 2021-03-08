#version 330 core
layout (location = 0) out vec4 FragColor;

in vec2 voUV;

uniform sampler2D uTexture0;

uniform bool horizontal;
const float weight[5]=float[](.2270270270,.1945945946,.1216216216,.0540540541,.0162162162);

void main()
{
    vec2 tex_size = textureSize(uTexture0,0);
    vec2 tex_offset = 1./tex_size; // gets size of single texel
    //tex_offset *= 0;

    vec3 result = texture(uTexture0,voUV).rgb * weight[0];
#if 1
    if(horizontal)
    {
        for(int i=1;i<5;++i)
        {
            result += texture(uTexture0, voUV + vec2(tex_offset.x * i, 0.)).rgb * weight[i];
            result += texture(uTexture0, voUV - vec2(tex_offset.x * i, 0.)).rgb * weight[i];
        }
    }
    else
    {
        for(int i=1;i<5;++i)
        {
            result += texture(uTexture0, voUV + vec2(0., tex_offset.y * i)).rgb * weight[i];
            result += texture(uTexture0, voUV - vec2(0., tex_offset.y * i)).rgb * weight[i];
        }
    }
    #endif

    if (isnan(result.r))
    {
    	//discard;
    }

    FragColor = vec4(result ,1.);
}
