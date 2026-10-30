// Just enough of the Metal Shading Language for clang to check a shader's
// syntax, names and types away from a Mac. Nothing here computes: the
// functions only have the shapes Metal gives them. See check.sh.
#pragma once
#define vertex
#define fragment
#define kernel
#define device
#define constant
#define thread
#define threadgroup
#define METAL_FUNC inline

typedef unsigned int uint;
typedef unsigned short ushort;
typedef unsigned char uchar;
typedef float half;

#define NM_VEC(T)                                                    \
    typedef T T##2 __attribute__((ext_vector_type(2)));              \
    typedef T T##3 __attribute__((ext_vector_type(3)));              \
    typedef T T##4 __attribute__((ext_vector_type(4)));
NM_VEC(float)
NM_VEC(int)
NM_VEC(uint)
NM_VEC(short)
NM_VEC(ushort)
NM_VEC(char)
NM_VEC(uchar)
typedef float half2 __attribute__((ext_vector_type(2)));
typedef float half3 __attribute__((ext_vector_type(3)));
typedef float half4 __attribute__((ext_vector_type(4)));
typedef int bool2 __attribute__((ext_vector_type(2)));
typedef int bool3 __attribute__((ext_vector_type(3)));
typedef int bool4 __attribute__((ext_vector_type(4)));
typedef float3 packed_float3;
typedef float2 packed_float2;
typedef float4 packed_float4;
typedef char4 packed_char4;
typedef uchar4 packed_uchar4;
typedef ushort2 packed_ushort2;

// How many components a constructor's argument gives.
template <class T> struct nm_count { static constexpr int n = 1; };
#define NM_COUNT(T)                                                         \
    template <> struct nm_count<T##2> { static constexpr int n = 2; };     \
    template <> struct nm_count<T##3> { static constexpr int n = 3; };     \
    template <> struct nm_count<T##4> { static constexpr int n = 4; };
NM_COUNT(float)
NM_COUNT(int)
NM_COUNT(uint)
NM_COUNT(short)
NM_COUNT(ushort)
NM_COUNT(char)
NM_COUNT(uchar)
template <class... A> constexpr int nm_sum() { return (0 + ... + nm_count<A>::n); }

// `float4(a, b)` and the like, rewritten by check.sh to `make_float4(a, b)`.
#define NM_MAKE(T, N)                                                                         \
    template <class... A> inline T##N make_##T##N(A... args) {                                \
        static_assert(sizeof...(A) == 1 || nm_sum<A...>() == N, #T #N " needs " #N " parts"); \
        return T##N{};                                                                        \
    }
#define NM_MAKES(T) NM_MAKE(T, 2) NM_MAKE(T, 3) NM_MAKE(T, 4)
NM_MAKES(float)
NM_MAKES(int)
NM_MAKES(uint)
NM_MAKES(short)
NM_MAKES(ushort)
NM_MAKES(char)
NM_MAKES(uchar)
template <class... A> inline float2 make_half2(A... a) { return make_float2(a...); }
template <class... A> inline float3 make_half3(A... a) { return make_float3(a...); }
template <class... A> inline float4 make_half4(A... a) { return make_float4(a...); }
template <class... A> inline int2 make_bool2(A... a) { return make_int2(a...); }
template <class... A> inline int3 make_bool3(A... a) { return make_int3(a...); }
template <class... A> inline int4 make_bool4(A... a) { return make_int4(a...); }

struct float2x2 { float2 c[2]; float2 &operator[](int); const float2 &operator[](int) const; };
struct float3x3 { float3 c[3]; float3 &operator[](int); const float3 &operator[](int) const; };
struct float4x4 { float4 c[4]; float4 &operator[](int); const float4 &operator[](int) const; };
float2 operator*(const float2x2 &, const float2 &);
float3 operator*(const float3x3 &, const float3 &);
float4 operator*(const float4x4 &, const float4 &);
float2x2 operator*(const float2x2 &, const float2x2 &);
float3x3 operator*(const float3x3 &, const float3x3 &);
float4x4 operator*(const float4x4 &, const float4x4 &);
float2x2 make_float2x2(float2, float2);
float2x2 make_float2x2(float);
float3x3 make_float3x3(float3, float3, float3);
float3x3 make_float3x3(float);
float4x4 make_float4x4(float4, float4, float4, float4);
float4x4 make_float4x4(float);
float3x3 transpose(float3x3);
float4x4 transpose(float4x4);
float determinant(float3x3);

namespace metal {
enum class filter { nearest, linear };
enum class mip_filter { none, nearest, linear };
enum class address { clamp_to_edge, repeat, mirrored_repeat, clamp_to_zero };
enum class compare_func { less, less_equal, greater, never, always };
enum class coord { normalized, pixel };
struct sampler {
    template <class... A> constexpr sampler(A...) {}
};
enum class access { read, write, sample, read_write };
// A texture of T gives four of T at a time.
template <class T> struct texel;
template <> struct texel<float> { typedef float4 type; };
template <> struct texel<int> { typedef int4 type; };
template <> struct texel<uint> { typedef uint4 type; };
template <class T, access A = access::sample> struct texture2d {
    template <class... X> typename texel<T>::type sample(sampler, float2, X...) const;
    typename texel<T>::type read(uint2, uint = 0) const;
    typename texel<T>::type read(ushort2, uint = 0) const;
    void write(typename texel<T>::type, uint2, uint = 0) const;
    uint get_width(uint = 0) const;
    uint get_height(uint = 0) const;
};
template <class T, access A = access::sample> struct depth2d {
    float sample(sampler, float2) const;
    float sample_compare(sampler, float2, float) const;
    uint get_width(uint = 0) const;
    uint get_height(uint = 0) const;
};
template <class T, access A = access::sample> struct texture2d_array {
    typename texel<T>::type sample(sampler, float2, uint) const;
};
template <class T, access A = access::sample> struct texturecube {
    typename texel<T>::type sample(sampler, float3) const;
};
}  // namespace metal
using metal::texture2d;

// Common, geometric and maths functions, for scalars and vectors alike.
#define NM_FUNCS(T)                                                     \
    T abs(T); T floor(T); T ceil(T); T fract(T); T round(T); T trunc(T); \
    T sqrt(T); T rsqrt(T); T exp(T); T exp2(T); T log(T); T log2(T);     \
    T sin(T); T cos(T); T tan(T); T asin(T); T acos(T); T atan(T);       \
    T sinh(T); T cosh(T); T tanh(T); T saturate(T); T sign(T);           \
    T dfdx(T); T dfdy(T); T fwidth(T);                                  \
    T min(T, T); T max(T, T); T pow(T, T); T powr(T, T); T atan2(T, T);  \
    T fmod(T, T); T step(T, T); T fmin(T, T); T fmax(T, T);              \
    T clamp(T, T, T); T mix(T, T, T); T smoothstep(T, T, T); T fma(T, T, T);
NM_FUNCS(float)
NM_FUNCS(float2)
NM_FUNCS(float3)
NM_FUNCS(float4)
int abs(int); int min(int, int); int max(int, int); int clamp(int, int, int);
uint min(uint, uint); uint max(uint, uint); uint clamp(uint, uint, uint);
#define NM_VECTOR_ONLY(V)                                                    \
    float length(V); float length_squared(V); float distance(V, V);         \
    float distance_squared(V, V); float dot(V, V); V normalize(V);          \
    V reflect(V, V); V refract(V, V, float);                                \
    V min(V, float); V max(V, float); V clamp(V, float, float);             \
    V mix(V, V, float); V smoothstep(float, float, V); V step(float, V);    \
    V pow(V, float);
NM_VECTOR_ONLY(float2)
NM_VECTOR_ONLY(float3)
NM_VECTOR_ONLY(float4)
float3 cross(float3, float3);
template <class T, class C> T select(T, T, C);
bool any(int2); bool any(int3); bool any(int4); bool all(int2); bool all(int3); bool all(int4);
namespace metal {
namespace fast { using ::sin; using ::cos; using ::pow; using ::exp; using ::sqrt; using ::normalize; using ::length; using ::clamp; using ::saturate; }
namespace precise { using ::sin; using ::cos; using ::pow; using ::exp; using ::sqrt; }
using ::abs; using ::floor; using ::fract; using ::sqrt; using ::sin; using ::cos; using ::mix; using ::clamp; using ::saturate;
using ::smoothstep; using ::step; using ::dot; using ::cross; using ::normalize; using ::length; using ::min; using ::max;
using ::pow; using ::exp; using ::reflect; using ::distance; using ::atan2; using ::fmod;
}
void discard_fragment();
float as_type_float(uint);
