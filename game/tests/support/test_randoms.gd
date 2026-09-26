extends RefCounted

const SimRandoms = preload("res://tests/support/randoms/sim_randoms.gd")
const LfsrRandoms = preload("res://tests/support/randoms/lfsr_randoms.gd")
const GameRandoms = preload("res://tests/support/randoms/game_randoms.gd")
const ZeroRandom = SimRandoms.ZeroRandom
const ZeroLfsrRandom = LfsrRandoms.ZeroLfsrRandom
const NonzeroLfsrRandom = LfsrRandoms.NonzeroLfsrRandom
const MicrosimLfsrRandom = LfsrRandoms.MicrosimLfsrRandom
const SequenceLfsrRandom = LfsrRandoms.SequenceLfsrRandom
const SequenceRandom = SimRandoms.SequenceRandom
const SparseRandom = SimRandoms.SparseRandom
const CountingRandom = SimRandoms.CountingRandom
const SequenceModuloRandom = LfsrRandoms.SequenceModuloRandom
const SequenceGameModuloRandom = GameRandoms.SequenceGameModuloRandom
const ZeroGameRandom = GameRandoms.ZeroGameRandom
const NonzeroGameRandom = GameRandoms.NonzeroGameRandom
const SequenceGameRandom = GameRandoms.SequenceGameRandom
