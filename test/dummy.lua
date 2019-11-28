require('parser')

setprefix('DUMMY')

declare_std()

enum [[DummyEnum]] {
	DUMMY_NONE = 0,
}

define {
	DUMMY_STRING = "dummy",
	DUMMY_BOOL = true,
	DUMMY_NUMBER = 42,
	DUMMY_ENUM_COUNT = enumcount [[DummyEnum]],
}

struct [[extern]] [[DummyExternStruct]] {
	value = float(),
}

struct [[DummyInnerStruct]] {
	some_int = int(),
}

struct [[DummyStruct]] {
	inner = DummyInnerStruct(),
	array2d_of_bool = bool(20, 20),
	array_of_inner = DummyInnerStruct(10),
}
