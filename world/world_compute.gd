@tool
class_name WorldCompute
extends CompositorEffect


var rd: RenderingDevice
var shader: RID
var pipeline: RID


func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	rd = RenderingServer.get_rendering_device()
	RenderingServer.call_on_render_thread(_initialize_compute)


# System notifications, we want to react on the notification that
# alerts us we are about to be destroyed.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if shader.is_valid():
			# Freeing our shader will also free any dependents such as the pipeline!
			rd.free_rid(shader)


#region Code in this region runs on the rendering thread.
# Compile our shader at initialization.
func _initialize_compute() -> void:
	rd = RenderingServer.get_rendering_device()
	if not rd:
		return

	# Compile our shader.
	#var shader_file := load("res://post_process_grayscale.glsl")
	var shader_source := RDShaderSource.new()
	shader_source.source_compute = world_compute_source
	#var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	var shader_spirv : RDShaderSPIRV = rd.shader_compile_spirv_from_source(shader_source)
	shader = rd.shader_create_from_spirv(shader_spirv)
	if shader.is_valid():
		pipeline = rd.compute_pipeline_create(shader)


# Called by the rendering thread every frame.
func _render_callback(p_effect_callback_type: EffectCallbackType, p_render_data: RenderData) -> void:
	if rd and p_effect_callback_type == EFFECT_CALLBACK_TYPE_POST_TRANSPARENT and pipeline.is_valid():
		# Get our render scene buffers object, this gives us access to our render buffers.
		# Note that implementation differs per renderer hence the need for the cast.
		var render_scene_buffers := p_render_data.get_render_scene_buffers()
		if render_scene_buffers:
			# Get our render size, this is the 3D render resolution!
			var size: Vector2i = render_scene_buffers.get_internal_size()
			if size.x == 0 and size.y == 0:
				return

			# We can use a compute shader here.
			@warning_ignore("integer_division")
			var x_groups := (size.x - 1) / 8 + 1
			@warning_ignore("integer_division")
			var y_groups := (size.y - 1) / 8 + 1
			var z_groups := 1

			#print_debug(size.y)

			# Create push constant.
			# Must be aligned to 16 bytes and be in the same order as defined in the shader.
			var push_constant := PackedFloat32Array([
				size.x,
				size.y,
				0.0,
				0.0,
			])

			# Loop through views just in case we're doing stereo rendering. No extra cost if this is mono.
			var view_count: int = render_scene_buffers.get_view_count()
			for view in view_count:
				# Get the RID for our color image, we will be reading from and writing to it.
				var input_image: RID = render_scene_buffers.get_color_layer(view)

				# Create a uniform set, this will be cached, the cache will be cleared if our viewports configuration is changed.
				var uniform := RDUniform.new()
				uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
				uniform.binding = 0
				uniform.add_id(input_image)
				var uniform_set := UniformSetCacheRD.get_cache(shader, 0, [uniform])

				# Run our compute shader.
				var compute_list := rd.compute_list_begin()
				rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
				rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
				rd.compute_list_set_push_constant(compute_list, push_constant.to_byte_array(), push_constant.size() * 4)
				rd.compute_list_dispatch(compute_list, x_groups, y_groups, z_groups)
				rd.compute_list_end()
#endregion


var world_compute_source = "
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;

// Our push constant
layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	vec2 reserved;
} params;


// params:
// p: arbitrary point in 3D space
// c: the center of our sphere
// r: the radius of our sphere
float distance_from_sphere(in vec3 p, in vec3 c, float r)
{
	return length(p - c) - r;
}

vec3 ray_march(in vec3 ro, in vec3 rd)
{
	float total_distance_traveled = 0.0;
	const int NUMBER_OF_STEPS = 32;
	const float MINIMUM_HIT_DISTANCE = 0.001;
	const float MAXIMUM_TRACE_DISTANCE = 1000.0;

	for (int i = 0; i < NUMBER_OF_STEPS; ++i)
	{
		// Calculate our current position along the ray
		vec3 current_position = ro + total_distance_traveled * rd;

		// We wrote this function earlier in the tutorial -
		// assume that the sphere is centered at the origin
		// and has unit radius
		float distance_to_closest = distance_from_sphere(current_position, vec3(0.0), 1.0);

		if (distance_to_closest < MINIMUM_HIT_DISTANCE) // hit
		{
			// We hit something! Return red for now
			return vec3(1.0, 0.0, 0.0);
		}

		if (total_distance_traveled > MAXIMUM_TRACE_DISTANCE) // miss
		{
			break;
		}

		// accumulate the distance traveled thus far
		total_distance_traveled += distance_to_closest;
	}

	// If we get here, we didn't hit anything so just
	// return a background color (black)
	return vec3(0.0);
}



// The code we want to execute in each invocation
void main() {
	ivec2 uv = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = ivec2(params.raster_size);

	// Prevent reading/writing out of bounds.
	if (uv.x >= size.x || uv.y >= size.y) {
		return;
	}

	vec2 uv_mapped = vec2(uv.x/float(size.x), uv.y/float(size.y)) * 2.0 - 1.0;

	vec3 camera_position = vec3(0.0, 0.0, -5.0);
	vec3 ro = camera_position;
	vec3 rd = vec3(uv_mapped, 1.0);

	// Read from our color buffer.
	vec4 color = imageLoad(color_image, uv);

	// Apply our changes.
	float gray = color.r * 0.2125 + color.g * 0.7154 + color.b * 0.0721;

	//color.rgb = vec3(gray);
	//color.rgb = vec3(uv.x/float(size.x), 0.0 , 0.0);
	color.rgb = ray_march(ro, rd);

	// Write back to our color buffer.
	imageStore(color_image, uv, color);
}




	"
