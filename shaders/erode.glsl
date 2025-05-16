#[compute]
#version 450
#extension GL_EXT_shader_atomic_float : require

layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;

// map is read/write, others are read-only
layout(set = 0, binding = 0, std430) buffer HeightmapBuffer
{ 
    float map[]; 
};

layout(push_constant, std430) uniform PushConstants
{
    int mapSize;
    int maxSteps;
    float inertia;
    float capacityFactor;
    float minCapacity;
    float depositRate;
    float erodeSpeed;
    float evaporateSpeed;
    float gravity;
    float startSpeed;
    float startWater;
    float time;
} pc;

const float EROSION_KERNEL  [9] = float[]
(
    0.05, 0.1, 0.05,
    0.1,  0.4, 0.1,
    0.05, 0.1, 0.05
);

float getKernelValue(int row, int col)
{
    return EROSION_KERNEL[row * 3 + col];
}

// function to calculate the height and the gradient
vec3 calculateHeightAndGradient(float posX, float posY)
{
    int DropletNodeX = int(posX);
    int DropletNodeY = int(posY);

    // Calculate droplet's offset inside the cell [0,1] range
    float OffsetX = posX - float(DropletNodeX);
    float OffsetY = posY - float(DropletNodeY);

    float x = OffsetX;
    float y = OffsetY;

    int idx_nw = DropletNodeY * pc.mapSize + DropletNodeX;

    float heightNW = map[idx_nw];
    float heightNE = map[idx_nw + 1];
    float heightSW = map[idx_nw + pc.mapSize];
    float heightSE = map[idx_nw + pc.mapSize + 1];

    // Calculate droplet's direction of flow with bilinear interpolation
    float gradientX = (heightNE - heightNW) * (1.0 - y) + (heightSE - heightSW) * y;
    float gradientY = (heightSW - heightNW) * (1.0 - x) + (heightSE - heightNE) * x;

    // Calculate height with bilinear interpolation
    float height = heightNW * (1.0 - x) * (1.0 - y) + heightNE * x * (1.0 - y) + heightSW * (1.0 - x) * y + heightSE * x * y;

    return vec3(gradientX, gradientY, height);
}

// Helper function to deposit sediment at the droplet's current cell
void depositSedimentAtCell(int DropletNodeX, int DropletNodeY, float OffsetX, float OffsetY, float amountToDeposit) {
    if (amountToDeposit <= 0.0) {
        return;
    }

    int idx_nw = DropletNodeY * pc.mapSize + DropletNodeX;

    if (DropletNodeX >= 0 && DropletNodeX < pc.mapSize && DropletNodeY >= 0 && DropletNodeY < pc.mapSize) {

        atomicAdd(map[idx_nw], amountToDeposit * (1.0 - OffsetX) * (1.0 - OffsetY));
        atomicAdd(map[idx_nw + 1], amountToDeposit * OffsetX       * (1.0 - OffsetY));
        atomicAdd(map[idx_nw + pc.mapSize ], amountToDeposit * (1.0 - OffsetX) * OffsetY);
        atomicAdd(map[idx_nw + pc.mapSize + 1], amountToDeposit * OffsetX       * OffsetY);
    }
}

// Simple 32-bit xorshift RNG in GLSL
uint rng_state;

void seed_rng()
{
    uvec2 uv = gl_GlobalInvocationID.xy;
    // simple bit-mixer: interleave high and low bits, then xor with time
    // ((x & 0xFFFF) << 16) | (y & 0xFFFF) gives a 32-bit unique seed per thread
    rng_state = ((uv.x & 0xFFFFu) << 16) | (uv.y & 0xFFFFu);
    // mix in time (scaled to ms) so each frame is different
    rng_state ^= uint(pc.time * 1000.0);
    // avoid zero-state
    if (rng_state == 0u) rng_state = 0xdeadbeefu;
}

// 32-bit xorshift from Marsaglia
uint xorshift32()
{
    uint x = rng_state;
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;
    rng_state = x;
    return x;
}

// uniform [0,1)
float randf()
{
    return float(xorshift32()) / 4294967295.0;
}


// Main kernel function executed by each thread
void main()
{
    seed_rng();

    float posX = randf() * float(pc.mapSize - 1);
    float posY = randf() * float(pc.mapSize - 1);
    float dirX = 0.0;
    float dirY = 0.0;
    float speed = pc.startSpeed;
    float water = pc.startWater;
    float sediment = 0.0;

    int nodeX = 0;
    int nodeY = 0;
    float offset_x = 0.0;
    float offset_y = 0.0;

    // Droplet simulation loop
    for (int lifetime = 0; lifetime < pc.maxSteps; lifetime++)
    {
        nodeX = int(posX);
        nodeY = int(posY);
        int dropletIndex = nodeY * pc.mapSize + nodeX;

        // Calculating droplet's offset inside the cell [0,1] range
        offset_x = posX - float(nodeX);
        offset_y = posY - float(nodeY);

        // Calculating droplet's height and direction of flow
        vec3 heightAndGradient = calculateHeightAndGradient(posX, posY);
        float currentHeight = heightAndGradient.z;

        // Updating the droplet's direction and position
        dirX = (dirX * pc.inertia - heightAndGradient.x * (1.0 - pc.inertia));
        dirY = (dirY * pc.inertia - heightAndGradient.y * (1.0 - pc.inertia));

        // Normalizing direction vector
        float len = length(vec2(dirX, dirY));

        if (len != 0) {
            dirX /= len;
            dirY /= len;
        }

        // Move droplet position
        posX += dirX;
        posY += dirY;

        // Stop simulating if droplet has flowed over the border edge
        if ((dirX == 0.0 && dirY == 0.0) || posX < 0.0 || 
        posX > float(pc.mapSize - 1) || posY < 0.0 || posY > float(pc.mapSize - 1))
        {
            depositSedimentAtCell(nodeX, nodeY, offset_x, offset_y, sediment);
            break;
        }

        // Find the droplet's new height and calculate the height difference
        float newHeight = calculateHeightAndGradient(posX, posY).z;
        float heightDelta = newHeight - currentHeight; // Positive if moving uphill

        // Calculate sediment capacity
        float sedimentCapacity = max(-heightDelta * speed * water * pc.capacityFactor, pc.minCapacity);

        // --- Deposition or Erosion ---
        if (sediment > sedimentCapacity || heightDelta > 0.0)
        {
            // Deposit sediment
            float amountToDeposit = (heightDelta > 0.0) ? min(heightDelta, sediment) : (sediment - sedimentCapacity) * pc.depositRate; // Exceed capacity, deposit fraction
            
            depositSedimentAtCell(nodeX, nodeY, offset_x, offset_y, amountToDeposit);

            sediment -= amountToDeposit;
            sediment = max(0.0, sediment);
        }
        else
        {
            // Erode terrain
            float amountToErode = min((sedimentCapacity - sediment) * pc.erodeSpeed, -heightDelta); // Can't erode more than height difference

            for (int i = -1; i < 2; i++)
            {
                for (int j = -1; j < 2; j++)
                {
                    int ix = clamp(nodeX + i, 0, pc.mapSize - 1);
                    int iy = clamp(nodeY + j, 0, pc.mapSize - 1);
                    float kernelWeight = getKernelValue(i + 1, j + 1);
                    float remove = amountToErode * kernelWeight;

                    int erodeIndex = iy * pc.mapSize + ix;

                    float actualRemove = min(remove, map[erodeIndex]);
                    atomicAdd(map[erodeIndex], -actualRemove); 

                    map[erodeIndex] = clamp(map[erodeIndex], 0.0, 1.0);

                    sediment += remove;
                }
            }
        }
    
        // Update speed and water amount
        speed = sqrt(speed * speed + heightDelta * pc.gravity); // Apply gravity, prevent negative speed squared
        water *= (1.0 - pc.evaporateSpeed); // Evaporate water
    }
}
