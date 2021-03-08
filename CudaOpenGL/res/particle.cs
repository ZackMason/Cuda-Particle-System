#version 430

layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

layout( std140, binding = 4 ) buffer Mats
{
    mat4 Matrices[ ];
};

layout( rgba32f, binding = 0) uniform image2D Pos;
layout( rgba32f, binding = 1) uniform image2D Vel;
layout( rgba32f, binding = 2) uniform image2D Life;

vec3 hash3(float n){return fract(sin(vec3(n,n+1.,n+2.))*43758.5453123);}

layout (std140) uniform uGlobals
{
    float uTime;
};

uniform float dt;

void main()
{
    uint id = gl_GlobalInvocationID.x;
    ivec2 uv = ivec2(id%1024,id/1024);

    float t = imageLoad(Life,uv).x;
    float s = imageLoad(Life,uv).y;
    //s = 0.01;

    vec3 v = imageLoad(Vel,uv).xyz;

    vec3 f = v * t + .5 * vec3(0,-4,0) * t * t;

    vec3 sp = imageLoad(Pos,uv).xyz;

    vec3 p = imageLoad(Pos,uv).xyz + v * dt;
    vec3 a = normalize(vec3(sin(uTime)*14.,sin(uTime)*14.,0)-p) * dot(p,p)*.015;
    a += normalize(vec3(-sin(uTime)*14.,-sin(uTime)*14.,0)-p) * dot(p,p)*.015;
    a += normalize(vec3(0,cos(uTime)*14.,-sin(uTime)*14.)-p) * dot(p,p)*.015;
    a += -normalize(vec3(0,-cos(uTime)*14.,-sin(uTime)*14.)-p) / dot(p,p)*500.;
    a += vec3(0,-4,0);
    imageStore(Pos,uv,vec4(p,0));
    imageStore(Vel,uv,vec4(v + (a * dt),0));

    // create transform matrix

    Matrices[id] = mat4(vec4(s,0,0,0),
                        vec4(0,s,0,0),
                        vec4(0,0,s,0),
                        vec4(p,1));
}