#[compute]
#version 450
#extension GL_EXT_shader_atomic_float : require

layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0) buffer Heightmap {
    float height[];
};

layout(push_constant) uniform Params {
    int map_size;
    int num_iterations;
    float talus_angle;
    float thermal_factor;
    float height_scale;
};

void main() {
    uint idx = gl_GlobalInvocationID.x;
    int size = map_size;
    if (idx >= size * size) return;

    for (int iter = 0; iter < num_iterations; ++iter) {
        int y = int(idx) / size;
        int x = int(idx) % size;
        if (x == 0 || y == 0 || x == size - 1 || y == size - 1) continue;

        float h = height[idx] * height_scale;
        float diffs[4];
        int n_idx[4];
        n_idx[0] = (y - 1) * size + x; // up
        n_idx[1] = (y + 1) * size + x; // down
        n_idx[2] = y * size + (x - 1); // left
        n_idx[3] = y * size + (x + 1); // right

        float total_diff = 0.0;
        for (int i = 0; i < 4; ++i) {
            float nh = height[n_idx[i]] * height_scale;
            float diff = h - nh;
            if (diff > talus_angle * height_scale) {
                diffs[i] = diff;
                total_diff += diff;
            } else {
                diffs[i] = 0.0;
            }
        }
        if (total_diff > 0.0) {
            for (int i = 0; i < 4; ++i) {
                if (diffs[i] > 0.0) {
                    float move = thermal_factor * (diffs[i] - talus_angle * height_scale) / 4.0 / height_scale;
                    atomicAdd(height[idx], -move);
                    atomicAdd(height[n_idx[i]], move);
                }
            }
        }
        barrier();
    }
}