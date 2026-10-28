using System.Text.Json;
using System.Text.Json.Serialization;
using Na.Application;

namespace Na.Api;

internal sealed class ActivationStatusConverter : JsonConverter<ActivationStatus>
{
    public override ActivationStatus Read(ref Utf8JsonReader reader, Type typeToConvert, JsonSerializerOptions options) =>
        ActivationStatusNames.Parse(reader.GetString()!);

    public override void Write(Utf8JsonWriter writer, ActivationStatus value, JsonSerializerOptions options) =>
        writer.WriteStringValue(value.ToWireName());
}
