#[compute]
#version 450

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
    int coordX = int(posX);
    int coordY = int(posY);

    // Calculate droplet's offset inside the cell [0,1] range
    float x = posX - float(coordX);
    float y = posY - float(coordY);

    // Calculate heights of the four nodes of the droplet's cell
    int nodeIndexNW = coordY * pc.mapSize + coordX;
    float heightNW = map[nodeIndexNW];
    float heightNE = map[min(nodeIndexNW + 1, pc.mapSize * pc.mapSize - 1)];
    float heightSW = map[min(nodeIndexNW + pc.mapSize, pc.mapSize * pc.mapSize - 1)];
    float heightSE = map[min(nodeIndexNW + pc.mapSize + 1, pc.mapSize * pc.mapSize - 1)];

    // Calculate droplet's direction of flow with bilinear interpolation
    float gradientX = (heightNE - heightNW) * (1.0 - y) + (heightSE - heightSW) * y;
    float gradientY = (heightSW - heightNW) * (1.0 - x) + (heightSE - heightNE) * x;

    // Calculate height with bilinear interpolation
    float height = heightNW * (1.0 - x) * (1.0 - y) + heightNE * x * (1.0 - y) + heightSW * (1.0 - x) * y + heightSE * x * y;

    return vec3(gradientX, gradientY, height);
}

// —————————————————————————————
// Simple 32-bit xorshift RNG in GLSL
// —————————————————————————————

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

    for (int lifetime = 0; lifetime < pc.maxSteps; lifetime++)
    {
        int nodeX = int(posX);
        int nodeY = int(posY);
        int dropletIndex = nodeY * pc.mapSize + nodeX;

        // Calculating droplet's offset inside the cell [0,1] range
        float offset_x = posX - float(nodeX);
        float offset_y = posY - float(nodeY);

        // Calculating droplet's height and direction of flow
        vec3 heightAndGradient = calculateHeightAndGradient(posX, posY);
        float currentHeight = heightAndGradient.z;

        // Updating the droplet's direction and position
        dirX = (dirX * pc.inertia - heightAndGradient.x * (1.0 - pc.inertia));
        dirY = (dirY * pc.inertia - heightAndGradient.y * (1.0 - pc.inertia));

        // Normalizing direction vector
        float len = length(vec2(dirX, dirY));
        
        if (len == 0.0)
        {
            break; // No flow, exit the loop
        }

        dirX /= len;
        dirY /= len;

        // Move droplet position
        posX += dirX;
        posY += dirY;

        // Stop simulating if droplet has flowed over the border edge
        // Use borderSize passed via push constants
        if (water <= 0.0 || (dirX == 0.0 && dirY == 0.0) || posX < 0.0 ||
            posX > float(pc.mapSize - 1) || posY < 0.0 || posY > float(pc.mapSize - 1))
        {
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
            sediment -= amountToDeposit;

            // Distribute deposit bilinearly onto the four neighbor nodes
            // atomicAdd(map[dropletIndex], amountToDeposit * (1.0 - offset_x) * (1.0 - offset_y));
            // atomicAdd(map[dropletIndex + 1], amountToDeposit * offset_x       * (1.0 - offset_y));
            // atomicAdd(map[dropletIndex + pc.mapSize], amountToDeposit * (1.0 - offset_x) * offset_y);
            // atomicAdd(map[dropletIndex + pc.mapSize + 1], amountToDeposit * offset_x       * offset_y);


            map[dropletIndex]                 += amountToDeposit * (1.0 - offset_x) * (1.0 - offset_y);
            map[dropletIndex + 1]             += amountToDeposit * offset_x       * (1.0 - offset_y);
            map[dropletIndex + pc.mapSize]    += amountToDeposit * (1.0 - offset_x) * offset_y;
            map[dropletIndex + pc.mapSize + 1]+= amountToDeposit * offset_x       * offset_y;

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
                    map[iy * pc.mapSize + ix] = clamp(map[iy * pc.mapSize + ix] - remove, 0.0, 1.0);
                    sediment += remove;
                }
            }
        }
    
        // Update speed and water amount
        speed = sqrt(max(0.0, speed * speed + heightDelta * pc.gravity)); // Apply gravity, prevent negative speed squared
        water *= (1.0 - pc.evaporateSpeed); // Evaporate water
    }
}
