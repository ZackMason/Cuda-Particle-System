#version 430

layout(local_size_x = 100, local_size_y = 10, local_size_z = 1) in;

layout( std140, binding = 0 ) buffer Position
{
    vec4 Pos[ ];
};

layout( std140, binding = 1 ) buffer Velocity
{
    vec4 Vel[ ];
};

layout( std140, binding = 2 ) buffer Settings
{
    vec4 Stats[ ];
};

vec3 hash3(float n){return fract(sin(vec3(n,n+1.,n+2.))*43758.5453123);}

uniform float dt;

void main()
{

    int id = int(gl_GlobalInvocationID.x);

    vec4 P = Pos[id];
    vec4 V = Vel[id];

    float t = Stats[id].x + dt;

    if(t < 0.0)
    {
        P = vec4(0);
        V = vec4(0);
        t = hash3(float(id)).x;
    }
    
    V += vec4(-sin(t), cos(t), 0, 0) * dt;
    P += V.xyzw * dt;

    Pos[id] = P;
    Vel[id] = V;
    Stats[id].x = t;
}