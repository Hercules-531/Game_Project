extends RefCounted
## Native deterministic PCM. No recordings or imported audio are required.
const RATE := 22050
static var cache: Dictionary = {}
const DURATIONS = {"motor":1.0,"wind":2.0,"rain":2.0,"vent":1.0,"step":0.16,"claw":0.22,"impact":0.3,"drill":0.6,"rail":0.45,"sonar":0.25,"echo":0.13,"contact":0.22,"alarm":0.4,"critical":0.3,"breath":1.4}
static func stream(cue: String) -> AudioStreamWAV:
	if cache.has(cue): return cache[cue]
	assert(DURATIONS.has(cue))
	var samples := int(RATE*DURATIONS[cue])
	var bytes := PackedByteArray()
	bytes.resize(samples*2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4117+cue.hash()
	var smoothed := 0.0
	for i in samples:
		var t := float(i)/RATE
		var p := float(i)/samples
		var noise := rng.randf_range(-1,1)
		smoothed = smoothed*0.92+noise*0.08
		var sample := 0.0
		match cue:
			"motor": sample = sin(TAU*64*t)*0.5+sin(TAU*128*t)*0.12+smoothed*0.4
			"wind": sample = smoothed*(0.8+0.2*sin(TAU*0.5*t))
			"rain": sample = noise*0.25+smoothed*0.4
			"vent": sample = sin(TAU*48*t)*0.14+smoothed*0.55
			"step","claw": sample = (smoothed*3+sin(TAU*(95 if cue=="step" else 180)*t)*0.35)*exp(-p*8)
			"impact": sample = (noise*0.3+sin(TAU*113*t)*0.5+sin(TAU*307*t)*0.2)*exp(-p*7)
			"drill": sample = sin(TAU*96*t)*0.3+noise*0.25+sin(TAU*384*t)*0.16
			"rail": sample = (sin(TAU*170*t)*0.3+noise*0.18)*(0.4+0.6*pow(absf(sin(TAU*5*t)),8))
			"sonar": sample = sin(TAU*(1100*t-600*t*t))*0.65
			"echo": sample = sin(TAU*760*t)*0.5*exp(-p*4)
			"contact": sample = sin(TAU*(980 if p<0.45 else 1240)*t)*0.5
			"alarm","critical": sample = sin(TAU*(540 if cue=="alarm" else 880)*t)*0.55
			"breath": sample = smoothed*2.0*pow(sin(PI*p),2)
		var envelope := minf(1,minf(p/0.025,(1-p)/0.04))
		bytes.encode_s16(i*2,int(clampf(sample*envelope*0.65,-0.82,0.82)*32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	if cue in ["motor","wind","rain","vent"]:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = samples
	cache[cue] = wav
	return wav
