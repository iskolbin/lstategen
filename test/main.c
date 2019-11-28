struct DummyExternStruct {
	float value;
};

#include "state.h"
#include "serialize.h"
#include "deserialize.h"

int main() {
	struct DummyStruct s = {.array_of_inner = {{.some_int = 22}}};
	FILE *f = fopen("dummy.json", "w+");
	DUMMY_SERIALIZE_DummyStruct(f, &s);
	fclose(f);
	return 0;
}
