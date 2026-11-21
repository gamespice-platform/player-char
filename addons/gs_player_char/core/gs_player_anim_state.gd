class_name GSPlayerAnimState
extends GSAnimationLocomotion

## Which locomotion state a character is in, as a pure function of how it is moving.
##
## The state machine and its hysteresis moved to GameSpice Animation ([GSAnimationLocomotion]); this keeps the name games and this addon's [GSPlayerAnimDriver] use. Nothing is added: the vocabulary constants, thresholds and [method advance] are inherited unchanged.


func _to_string() -> String:
	return "GSPlayerAnimState(%s)" % describe()
