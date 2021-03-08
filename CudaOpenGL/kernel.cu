#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#include <stdio.h>
#include <stdint.h>
#include <iostream>
#include <array>
#include <cstddef>

#include <glad/glad.h>
#include <GLFW/glfw3.h>

#include "ImGUI/imgui.h"
#include "ImGUI/imgui_impl_glfw.h"
#include "ImGUI/imgui_impl_opengl3.h"

#include "cuda_gl_interop.h"
#include "curand.h"
#include "curand_kernel.h"

#include "Types.h"
#include "Shader.h"
#include "TripRandom.h"
#include "ComputeShader.h"

static const char *_cudaGetErrorEnum(cudaError_t error)
{
	return cudaGetErrorName(error);
}

template <typename T>
void check(T result, char const *const func, const char *const file,int const line)
{
	if (result) 
	{
		fprintf(stderr, "CUDA error at %s:%d code=%d(%s) \"%s\" \n", file, line,
			static_cast<unsigned int>(result), _cudaGetErrorEnum(result), func);
		exit(EXIT_FAILURE);
	}
}
#define checkCudaErrors(val) check((val), #val, __FILE__, __LINE__)

void GLAPIENTRY
MessageCallback(GLenum source,
	GLenum type,
	GLuint id,
	GLenum severity,
	GLsizei length,
	const GLchar* message,
	const void* userParam)
{
	if (severity > GL_DEBUG_SEVERITY_LOW)
		fprintf(stderr, "GL CALLBACK: %s type = 0x%x, severity = 0x%x, message = %s\n",
		(type == GL_DEBUG_TYPE_ERROR ? "** GL ERROR **" : ""),
			type, severity, message);
}

template<class T>
constexpr const T& clamp(const T& v, const T& lo, const T& hi)
{
	assert(!(hi < lo));
	return (v < lo) ? lo : (hi < v) ? hi : v;
}

constexpr u32 SIZE = 1024;
constexpr u32 WIDTH = 840;
constexpr u32 HEIGHT = 600;

__device__ float generate(curandState* globalState, int ind)
{
	//int ind = threadIdx.x;
	curandState localState = globalState[ind%5];
	float RANDOM = curand_uniform(&localState);
	globalState[ind%5] = localState;
	return RANDOM;
}

__global__ void RandInit(curandState* state, int seed)
{
	curand_init(seed, threadIdx.x,  0, &state[threadIdx.x]);
}


__global__ void ParticleSim(f32 dt,
	float3* pos,
	float3* vel,
	float1* life,
	float3* col,
	curandState* state,
	float3 ParticleColor,
	bool bSpawn
)
{
	u32 i = threadIdx.x + blockIdx.x * blockDim.x;

	v3 inPos = { pos[i].x, pos[i].y, pos[i].z };
	v3 inCol = { col[i].x, col[i].y, col[i].z };
	v3 inVel = { vel[i].x, vel[i].y, vel[i].z };
	f32 inLife = { life[i].x - dt};
	
	if (bSpawn && inLife < 0.0f)
	{
		float r = generate(state, i) * 2.0 * 3.1415926;
		inPos = v3(cos(r)*10.1f, sin(r)*10.1f, 0.f);
		//inPos = v3(0.f, generate(state,i) * 6.0f - 3.0f, 0.f);
		//inPos = v3(generate(state, i));
		inLife = 6.0f * generate(state,i);
		//inCol = v3(generate(state, i), generate(state, i) * .5f, generate(state, i) * 0.3f) * 0.5f + 0.5f;
		inCol = v3(ParticleColor.x, ParticleColor.y, ParticleColor.z) * v3(generate(state, i)) * 0.75f + 0.25f;
		inVel = v3(generate(state, i)* 2.0f - 1.0f, generate(state, i), generate(state, i) * 2.0f - 1.0f);
	}
	inCol = inCol;// *glm::min(1.0f, inLife);
	inPos = inPos + (inVel * dt);
	//inVel += v3(cosf(inPos.x), 0., sinf(inPos.z));
	//inVel += v3(inPos.z * inPos.z * inPos.z, 0., inPos.x * inPos.x * inPos.x);

	f32 t = atan2(inPos.z, inPos.x);
	//f32 phi = atan2(glm::length(inPos) , inPos.y);
	inVel += v3(sinf(t), -inPos.y*.3f, -cosf(t))* dt * 10.f;
	inVel += -glm::normalize(inPos) * dt;
	//inVel += v3(0,0,-10) * dt;
	//inVel += v3(-2.f * inPos.x + 2.f * inPos.z , 0, -3.f * inPos.x - 3.f * inPos.z) * dt * 2.f;
	
	pos[i] = make_float3(inPos.x, inPos.y, inPos.z);
	col[i] = make_float3(inCol.x, inCol.y, inCol.z);
	vel[i] = make_float3(inVel.x, inVel.y - dt * .3f, inVel.z);
	life[i].x = inLife;
}

__global__ void InvertColor(float4* pbo)
{
	u32 i = threadIdx.x + blockIdx.x * blockDim.x;
	pbo[i] = make_float4(1.0f - pbo[i].x, 1.0f - pbo[i].y, 1.0f - pbo[i].z, 1.0f);
}

static bool s_Run = true;

unsigned int quadVAO = 0;
unsigned int quadVBO;
void renderQuad()
{
	if (quadVAO == 0)
	{
		float quadVertices[] = {
			// positions        // texture Coords
			-1.0f,  1.0f, 0.0f, 0.0f, 1.0f,
			-1.0f, -1.0f, 0.0f, 0.0f, 0.0f,
			 1.0f,  1.0f, 0.0f, 1.0f, 1.0f,
			 1.0f, -1.0f, 0.0f, 1.0f, 0.0f,
		};
		// setup plane VAO
		glGenVertexArrays(1, &quadVAO);
		glGenBuffers(1, &quadVBO);
		glBindVertexArray(quadVAO);
		glBindBuffer(GL_ARRAY_BUFFER, quadVBO);
		glBufferData(GL_ARRAY_BUFFER, sizeof(quadVertices), &quadVertices, GL_STATIC_DRAW);
		glEnableVertexAttribArray(0);
		glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 5 * sizeof(float), (void*)0);
		glEnableVertexAttribArray(1);
		glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, 5 * sizeof(float), (void*)(3 * sizeof(float)));
	}
	glBindVertexArray(quadVAO);
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
	glBindVertexArray(0);
}

enum class eProgramState : u32
{
	NORMAL, SLOW_MO, PAUSED, SIZE
};

int main()
{
	eProgramState ProgState = eProgramState::NORMAL;
	
	glfwInit();
	glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
	glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 4);
	glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
	glfwWindowHint(GLFW_SAMPLES, 4);
	// glfw window creation
	// --------------------
	GLFWwindow* window = glfwCreateWindow(WIDTH, HEIGHT, "CudaGL", nullptr, nullptr);
	if (window == nullptr)
	{
		std::cerr << "Failed to create GLFW window.\n";
		glfwTerminate();
	}
	else
	{
		std::cerr << "GLFW Create Window Succesful!\n";
		glfwMakeContextCurrent(window);
	}

	GLFWmonitor* monitor = glfwGetPrimaryMonitor();
	const GLFWvidmode *mode = glfwGetVideoMode(monitor);
	if (mode)
	{
		i32 monitorX, monitorY;
		glfwGetMonitorPos(monitor, &monitorX, &monitorY);
		glfwSetWindowPos(window, monitorX + (mode->width - WIDTH) / 2, monitorY + (mode->height - HEIGHT) / 2);
	}

	// load opengl
	if (!gladLoadGLLoader(reinterpret_cast<GLADloadproc>(glfwGetProcAddress)))
	{
		std::cerr << "Failed to initialize GLAD\n";
		std::cin.get();
		exit(1);
	}

	glfwSetWindowCloseCallback(window, [](GLFWwindow* window) {s_Run = false; });

	struct WindowData
	{
		f32 Scroll = {};
	} winData;

	glfwSetWindowUserPointer(window, &winData);

	glfwSetScrollCallback(window, [](GLFWwindow* win, f64 x, f64 y)
	{
		WindowData& data = *static_cast<WindowData*>(glfwGetWindowUserPointer(win));
		data.Scroll = y;
	});

	IMGUI_CHECKVERSION();
	ImGui::CreateContext();
	ImGuiIO& io = ImGui::GetIO(); (void)io;
	io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard;       // Enable Keyboard Controls
	//io.ConfigFlags |= ImGuiConfigFlags_NavEnableGamepad;      // Enable Gamepad Controls
	io.ConfigFlags |= ImGuiConfigFlags_DockingEnable;           // Enable Docking
	io.ConfigFlags |= ImGuiConfigFlags_ViewportsEnable;         // Enable Multi-Viewport / Platform Windows

	//io.ConfigViewportsNoAutoMerge = true;
	//io.ConfigViewportsNoTaskBarIcon = true;

	io.DisplaySize = ImVec2(WIDTH, HEIGHT);

	// Setup Dear ImGui style
	ImGui::StyleColorsDark();
	//ImGui::StyleColorsClassic();

	// When viewports are enabled we tweak WindowRounding/WindowBg so platform windows can look identical to regular ones.
	ImGuiStyle& style = ImGui::GetStyle();
	if (io.ConfigFlags & ImGuiConfigFlags_ViewportsEnable)
	{
		style.WindowRounding = 0.0f;
		style.Colors[ImGuiCol_WindowBg].w = 1.0f;
	}

	// Setup Platform/Renderer bindings
	ImGui_ImplGlfw_InitForOpenGL(window, true);
	ImGui_ImplOpenGL3_Init("#version 130");


	
	// init cuda rand
	curandState* devStates;
	cudaMalloc(&devStates, 5 * sizeof(curandState));
	RandInit<<<1,5>>>(devStates, TripRandom::Float() * 100);
	
	printf("OPENGL VERSION: %s\n", glGetString(GL_VERSION));

	glEnable(GL_DEPTH_TEST);
	glEnable(GL_DEBUG_OUTPUT);
	glDebugMessageCallback(MessageCallback, nullptr);
	glPointSize(3.0f);

//	glBlendFunc(GL_ONE, GL_ONE);

	// setup particle system 
	cudaGraphicsResource *cuda_pos_vbo_res;
	cudaGraphicsResource *cuda_col_vbo_res;
	cudaGraphicsResource *cuda_vel_vbo_res;
	cudaGraphicsResource *cuda_life_vbo_res;

	u32 VAO;
	u32 posVBO;
	u32 colVBO;
	u32 velVBO;
	u32 lifeVBO;
	
	//constexpr auto ParticleCount = 40'000'000;
	constexpr auto ParticleCount = 40'000'000;
	
	glGenVertexArrays(1, &VAO);
	glBindVertexArray(VAO);

	glGenBuffers(1, &posVBO);
	glBindBuffer(GL_ARRAY_BUFFER, posVBO);
	glBufferData(GL_ARRAY_BUFFER, ParticleCount * sizeof(v3), 0, GL_DYNAMIC_DRAW); // posVBO_Buffer.data(), GL_DYNAMIC_DRAW);
	glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
	glEnableVertexAttribArray(0);
	checkCudaErrors(cudaGraphicsGLRegisterBuffer(&cuda_pos_vbo_res, posVBO, cudaGraphicsMapFlagsNone));

	glGenBuffers(1, &colVBO);
	glBindBuffer(GL_ARRAY_BUFFER, colVBO);
	glBufferData(GL_ARRAY_BUFFER, ParticleCount * sizeof(v3), 0, GL_DYNAMIC_DRAW); 
	glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 3 * sizeof(float), (void*)0);
	glEnableVertexAttribArray(1);
	checkCudaErrors(cudaGraphicsGLRegisterBuffer(&cuda_col_vbo_res, colVBO, cudaGraphicsMapFlagsNone));
	
	glBindVertexArray(0);

	glGenBuffers(1, &velVBO);
	glBindBuffer(GL_ARRAY_BUFFER, velVBO);
	glBufferData(GL_ARRAY_BUFFER, ParticleCount * sizeof(v3), 0, GL_DYNAMIC_DRAW);
	checkCudaErrors(cudaGraphicsGLRegisterBuffer(&cuda_vel_vbo_res, velVBO, cudaGraphicsMapFlagsNone));

	glGenBuffers(1, &lifeVBO);
	glBindBuffer(GL_ARRAY_BUFFER, lifeVBO);
	glBufferData(GL_ARRAY_BUFFER, ParticleCount * sizeof(f32), 0, GL_DYNAMIC_DRAW);
	checkCudaErrors(cudaGraphicsGLRegisterBuffer(&cuda_life_vbo_res, lifeVBO, cudaGraphicsMapFlagsNone));

	glBindBuffer(GL_ARRAY_BUFFER, 0);

	// setup framebuffers
	u32 FBO;
	u32 FBOColor[2]; // 0 : Scene color, 1 : scene brightness
	cudaGraphicsResource *cuda_fbo_res[2];

	glGenFramebuffers(1, &FBO);
	glBindFramebuffer(GL_FRAMEBUFFER, FBO);
	
	glGenTextures(2, FBOColor);

	for (unsigned int i = 0; i < 2; i++)
	{
		glBindTexture(GL_TEXTURE_2D, FBOColor[i]);

		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA16F, WIDTH, HEIGHT, 0, GL_RGBA, GL_FLOAT, NULL);

		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0 + i, GL_TEXTURE_2D, FBOColor[i], 0);
		//checkCudaErrors(cudaGraphicsGLRegisterImage(&cuda_fbo_res[i], FBOColor[i], GL_TEXTURE_2D, cudaGraphicsMapFlagsNone));
	}
	glBindTexture(GL_TEXTURE_2D, 0);

	unsigned int attachments[2] = { GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1 };
	glDrawBuffers(2, attachments);
	//glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, FBOColor, 0);

	u32 rbo;
	glGenRenderbuffers(1, &rbo);
	glBindRenderbuffer(GL_RENDERBUFFER, rbo);
	glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH24_STENCIL8, WIDTH, HEIGHT);
	glBindRenderbuffer(GL_RENDERBUFFER, 0);
	glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT, GL_RENDERBUFFER, rbo);
	if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
		std::cout << "ERROR::FRAMEBUFFER:: Framebuffer is not complete!" << std::endl;
	glBindFramebuffer(GL_FRAMEBUFFER, 0);

	// post processing framebuffers
	unsigned int pingpongFBO[2];
	unsigned int pingpongColorbuffers[2];
	glGenFramebuffers(2, pingpongFBO);
	glGenTextures(2, pingpongColorbuffers);
	for (unsigned int i = 0; i < 2; i++)
	{
		glBindFramebuffer(GL_FRAMEBUFFER, pingpongFBO[i]);
		glBindTexture(GL_TEXTURE_2D, pingpongColorbuffers[i]);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB16F, WIDTH, HEIGHT, 0, GL_RGB, GL_FLOAT, NULL);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE); // we clamp to the edge as the blur filter would otherwise sample repeated texture values!
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, pingpongColorbuffers[i], 0);

		// also check if framebuffers are complete (no need for depth buffer)
		if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
			std::cout << "Framebuffer not complete!" << std::endl;
	}
	glBindFramebuffer(GL_FRAMEBUFFER, 0);
	glBindTexture(GL_TEXTURE_2D, 0);

	static f32 sCurTime = glfwGetTime();
	static f32 sRunTime = 0.0f;
	static f32 sDT = 0.0f;

	// Camera
	m4 Proj = glm::perspective(45.0f, WIDTH / (f32)HEIGHT, 0.1f, 100.f);
	m4 View = glm::lookAt(v3(0, 0, 1), v3(0, 0, 0), v3(0, 1, 0));
	
	f32 camTheta = 90.f;
	f32 camPhi = 1.6f;
	f32 camRho = 10.0f;
	f32 maxCampRho = 50.f;
	v3 camPos = {};

	auto GetShpericalCoord = [](f32 t, f32 phi, f32 rho) -> v3
	{
		return {
			rho * cosf(t) * sinf(phi),
			rho * cosf(phi),
			rho * sinf(t) * sinf(phi)
		};
	};

	v2 MousePos = {};
	v2 LastMousePos = {};

	// Load Shaders
	Shader screen_shader("screen");
	screen_shader.Bind();
	screen_shader.setInt("uTexture0", 0);
	screen_shader.setInt("uTexture1", 1);
	screen_shader.setInt("uExp", 1.0f);
	f32 screen_shader_uExp = 1.0f;

	Shader blur_shader("blur");
	blur_shader.Bind();
	blur_shader.setInt("uTexture0", 0);
	blur_shader.setInt("horizontal", 0);
	
	Shader shader("shader", true);
	shader.Bind();
	shader.setMat4("uP", Proj);

	//ComputeShader ParticleSimShader("particleCreater");

	// ImGui Config

	float3 ParticleColor = make_float3(0.2f,0.2f,1.0f);
	
	// main loop
	while (s_Run)
	{
		sDT = glfwGetTime() - sCurTime;

		ImGui_ImplOpenGL3_NewFrame();
		ImGui_ImplGlfw_NewFrame();
		ImGui::NewFrame();

		{
			ImGui::Begin("Settings");
			ImGui::Text("fps: %.2f, Number of Particles: %d", ImGui::GetIO().Framerate, ParticleCount);
			ImGui::DragFloat("Exposure", &screen_shader_uExp, 0.1);
			ImGui::ColorEdit3("Particle Color", (float*)&ParticleColor);
			ImGui::End();
		}
		
		glBindFramebuffer(GL_FRAMEBUFFER, FBO);
		
		//glClearColor(0.2f, 0.3f, 0.3f, 1.0f);
		glClearColor(0.00002f, 0.00003f, 0.0003f, 1.0f);
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		
		// Input
		f64 mx, my;
		glfwGetCursorPos(window, &mx, &my);
		LastMousePos = MousePos;
		MousePos = { mx,my };

		if (glfwGetMouseButton(window, 1))
		{
			camPhi += (LastMousePos.y - MousePos.y) * sDT * 0.5f;
			camTheta -= (LastMousePos.x - MousePos.x) * sDT * 0.5f;
		}

		camRho += -winData.Scroll;
		winData.Scroll = 0.0f;

		if (glfwGetKey(window, GLFW_KEY_SPACE))
			ProgState = (ProgState == eProgramState::NORMAL) ? eProgramState::PAUSED : eProgramState::NORMAL;

		if (glfwGetKey(window, GLFW_KEY_C))
			ProgState = eProgramState::SLOW_MO;

		if (glfwGetKey(window, GLFW_KEY_I))
			screen_shader_uExp += 0.5 * sDT;
		if (glfwGetKey(window, GLFW_KEY_K))
			screen_shader_uExp -= 0.5 * sDT;
		
		if (glfwGetKey(window, GLFW_KEY_ESCAPE))
			s_Run = false;
		
		if (glfwGetKey(window, GLFW_KEY_A))
			camTheta += sDT;
		if (glfwGetKey(window, GLFW_KEY_D))
			camTheta -= sDT;

		if (glfwGetKey(window, GLFW_KEY_W))
			camPhi += sDT;
		if (glfwGetKey(window, GLFW_KEY_S))
			camPhi -= sDT;

		if (glfwGetKey(window, GLFW_KEY_R))
			camRho -= sDT;
		if (glfwGetKey(window, GLFW_KEY_F))
			camRho += sDT;

		if (glfwGetKey(window, GLFW_KEY_Z))
			maxCampRho += sDT;
		if (glfwGetKey(window, GLFW_KEY_X))
			maxCampRho -= sDT;

		bool bSpawn = true;
		if (glfwGetKey(window, GLFW_KEY_N))
			bSpawn = false;

		camRho = clamp(camRho, 0.1f, maxCampRho);
		camPhi = clamp(camPhi, 0.01f, glm::pi<f32>());
		
		camPos = GetShpericalCoord(camTheta, camPhi, camRho);
		View = glm::lookAt(camPos, v3(0, 0, 0), v3(0, 1, 0));
		shader.setMat4("uV", View);

		switch (ProgState)
		{
		case eProgramState::SLOW_MO:
			sDT *= 0.5f;
			break;
		case eProgramState::PAUSED:
			sDT = 0.0f;
			break;
		}

		sRunTime += sDT;
		sCurTime = glfwGetTime();

#if 1
		float3* d_pos_ptr;
		float3* d_col_ptr;
		float3* d_vel_ptr;
		float1* d_life_ptr;

		std::size_t num_bytes;
		checkCudaErrors(cudaGraphicsMapResources(1, &cuda_pos_vbo_res, 0));
		checkCudaErrors(cudaGraphicsResourceGetMappedPointer((void **)&d_pos_ptr,  &num_bytes, cuda_pos_vbo_res));

		checkCudaErrors(cudaGraphicsMapResources(1, &cuda_col_vbo_res, 0));
		checkCudaErrors(cudaGraphicsResourceGetMappedPointer((void **)&d_col_ptr, &num_bytes, cuda_col_vbo_res));
		
		checkCudaErrors(cudaGraphicsMapResources(1, &cuda_vel_vbo_res, 0));
		checkCudaErrors(cudaGraphicsResourceGetMappedPointer((void **)&d_vel_ptr,  &num_bytes, cuda_vel_vbo_res));
		
		checkCudaErrors(cudaGraphicsMapResources(1, &cuda_life_vbo_res, 0));
		checkCudaErrors(cudaGraphicsResourceGetMappedPointer((void **)&d_life_ptr, &num_bytes, cuda_life_vbo_res));

		//printf("CUDA mapped VBO: May access %ld bytes\n", num_bytes);

		ParticleSim<<<ParticleCount/1000, 1000>>>(sDT, 
			d_pos_ptr, d_vel_ptr, d_life_ptr, d_col_ptr, devStates, ParticleColor, bSpawn);

		checkCudaErrors(cudaGraphicsUnmapResources(1, &cuda_life_vbo_res, 0));
		checkCudaErrors(cudaGraphicsUnmapResources(1, &cuda_vel_vbo_res, 0));
		checkCudaErrors(cudaGraphicsUnmapResources(1, &cuda_col_vbo_res, 0));
		checkCudaErrors(cudaGraphicsUnmapResources(1, &cuda_pos_vbo_res, 0));
#endif

		//ParticleSimShader.Bind(ParticleCount, posVBO, velVBO, lifeVBO, sDT);
		
		glBindVertexArray(VAO);
		glDrawArrays(GL_POINTS, 0, ParticleCount);
		glBindVertexArray(0);

		glBindFramebuffer(GL_FRAMEBUFFER, 0);

		auto err = glGetError();
		blur_shader.Bind();
		blur_shader.setInt("uTexture0", 0);
		bool horizontal = true, first_iteration = true;
		unsigned int amount = 10;
		glActiveTexture(GL_TEXTURE0);
		for (unsigned int i = 0; i < amount; i++)
		{
			glBindFramebuffer(GL_FRAMEBUFFER, pingpongFBO[horizontal]);
			blur_shader.setInt("horizontal", horizontal);
			glBindTexture(GL_TEXTURE_2D, first_iteration ? FBOColor[1] : pingpongColorbuffers[!horizontal]);  // bind texture of other framebuffer (or scene if first iteration)
			renderQuad();
			horizontal = !horizontal;
			first_iteration = false;
		}
		err = glGetError();
		if(err)
		{
			printf("Error: %i\n", err);
		}
		
		glBindFramebuffer(GL_FRAMEBUFFER, 0);
		
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		screen_shader.Bind();
		screen_shader.setFloat("uExp", screen_shader_uExp);
		glActiveTexture(GL_TEXTURE0);
		glBindTexture(GL_TEXTURE_2D, FBOColor[0]);
		glActiveTexture(GL_TEXTURE1);
		glBindTexture(GL_TEXTURE_2D, pingpongColorbuffers[!horizontal]);
		
		renderQuad(); // display final results
		shader.Bind();

		ImGui::Render();
		ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());
		
		glfwSwapBuffers(window);
		glfwPollEvents();
	}

	checkCudaErrors(cudaGraphicsUnregisterResource(cuda_life_vbo_res));
	checkCudaErrors(cudaGraphicsUnregisterResource(cuda_pos_vbo_res));
	checkCudaErrors(cudaGraphicsUnregisterResource(cuda_col_vbo_res));
	checkCudaErrors(cudaGraphicsUnregisterResource(cuda_vel_vbo_res));

	glfwTerminate();
}