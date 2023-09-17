Rebol[]

audio: import miniaudio

sample-rate: 44100

test: [
with audio [
	; debug check
	print get-devices

	device: init-playback 1 ; TODO: allow manual selection

	snd.kick:  load %"snd/707 KICK 1.wav"
	snd.snare: load %"snd/707 SNARE 10.wav"

	start/at snd.kick 44100
	start/at snd.snare 88200
	start device
	
	loop 10 [
		print device/frames
		wait .25
	]

	start/at :snd.kick 132300
	start/at :snd.snare 154350
]
]

; NOTES: notes are word!s, letter, optional + (for sharp note) and octave
;
; EXAMPLE: C4, D+2, E-1 ; last example uses negative octave
;
; TODO: support b for flat, support -is and -es

fill-notes: func [
	/hz
] [
	result: make block! 150
	octave: -1
	notes: [C C+ D D+ E F F+ G G+ A A+ H]
	coef: 1.0594630943593
	freq: 8.175799

	repeat index 128 [
		note: first notes
		notes: next notes
		if empty? notes [
			notes: head notes
			octave: octave + 1
		]
		repend result [
			to set-word! rejoin [note octave]
			either hz [freq][index - 1]
		]
		freq: freq * coef
	]
	result
]

example: [
	; soundname: %file [note] ; default is c4

	bpm 120

	kick:  %"snd/707 KICK 1.wav"
	snare: %"snd/707 SNARE 10.wav"

	; timestamp sound velocity

	1.1.1.0 kick ;100
	1.1.3.0 snare
	1.2.1.0 kick
	1.2.3.0 snare
	1.3.1.0 kick
	1.3.3.0 snare
	1.4.2.0 kick
	1.4.3.0 snare

	2.1.1.0 stop
]

parse-seq: func [
	data
	/local
		rule
		name source
] [
	samples: make block! 20
	song: make song-proto []
	playlist: make block! 200
	rule: [
		'bpm set value integer!
		(song/tempo: value)
		some [
			set name set-word!
			set source file!
			(repend samples [name audio/load source])
		]
		some [
			set timestamp tuple! 'stop (
				timestamp: time-to-sample translate-time timestamp song sample-rate
				repend playlist [timestamp 'stop]
			)
		|	set timestamp tuple! set sample word!
			(
				timestamp: time-to-sample translate-time timestamp song sample-rate
				repend playlist [timestamp 'play sample]
			)
		]
	]
	parse data rule

	playlist
]

; simple drummer:
"K.s..kS."
;
; k - kick, K - kick with accent
; s - snare, o - open hat, c - closed hat, p - clap
; . - stop sound, _ - let sound continue


song-proto: context [
	tempo: 120      ; BPM
	resolution: 120 ; ticks
	signature: 4x4  ; 4/4
]

translate-time: func [
	time "Timestamp"
	song "Song object"
; #TODO "Needs to pass song object with tempo, resolution, etc."
	/local i value output
] [
; setup
	output: 0
	; FIXME: This probably not proper 
	tick: 60 / song/tempo * song/signature/y
; BAR
	value: time/1 - 1
	output: value * tick
; BEAT
	value: time/2 - 1
	output: output + (value * tick / song/signature/x)
; STEP
	value: time/3 - 1
	output: output + (value * tick / 16)
; TICK
	output: output + (time/4 * tick / (16 * song/resolution))
]

time-to-sample: func [
	"Convert time to sample offset"
	time
	sample-rate
] [
	to integer! time * sample-rate
]


; -----


seq: func [
	sequence
] [
	sequence: probe parse-seq sequence

	with audio [
		device: init-playback 1
;		snd.kick:  load %"snd/707 KICK 1.wav"
;		start/at snd.kick 0
		start device

		
		kick:  load %"snd/707 KICK 1.wav"

;		do bind take sequence audio

		window-time: 0.01
		frame-size: to integer! 44100 * window-time
		print ["Expected frame size:" frame-size]

		last-frame: 0

		loop 10000 [
			frames: device/frames
			print [
				"Actual frame size:" frames - last-frame newline
				"Frame:" frames
			]
			last-frame: frames

			parse sequence [
				set timestamp integer!
				'play
				set sound word!
				mark:
				(
					if timestamp < (frames + frame-size) [
						audio/start/at select samples sound timestamp
						print ["playing" mold sound "at" timestamp]
						sequence: mark
					]
				)
			]
			if frames > 100000 [break]
			wait window-time
		]
	]
]


;seq example
