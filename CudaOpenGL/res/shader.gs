#version 330 core
layout (points) in;
layout (triangle_strip, max_vertices = 4) out;

out vec3 oColor;

in VS_OUT {
    vec3 color;
} gs_in[];  

out GS_OUT
{
    vec3 Pos;
    vec2 UV;
} gs_out;

const float size = .052;

void build(vec4 position)
{    
    gl_Position = position + vec4(-size, -size, 0.0, 0.0);    // 1:bottom-left
    gs_out.UV = vec2(0,0);
    EmitVertex();   
    gl_Position = position + vec4(size, -size, 0.0, 0.0);    // 2:bottom-right
    gs_out.UV = vec2(1,0);
    EmitVertex();
    gl_Position = position + vec4(-size,  size, 0.0, 0.0);    // 3:top-left
    gs_out.UV = vec2(0,1);
    EmitVertex();
    gl_Position = position + vec4( size, size, 0.0, 0.0);    // 4:top-right
    gs_out.UV = vec2(1,1);
    EmitVertex();
    EndPrimitive();
}

void main()
{
    gs_out.UV = vec2(0,0);
    oColor = gs_in[0].color;
    build(gl_in[0].gl_Position);
}