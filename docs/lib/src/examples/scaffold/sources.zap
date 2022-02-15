<script>
  import 'dart:convert';
  import 'dart:html';

  import 'package:collection/collection.dart';

  import '../component.dart';

  final allSources = loadSources();

  final current = watch(selectedComponent);
  Future<ExampleWithSources?> currentSources = Future.value(null);
  $: currentSources = allSources.then((all) {
    return all.firstWhereOrNull((e) => e.id == current.id);
  });
</script>
<script context="library">
class ExampleWithSources {
  final String id;
  final List<SourceFile> files;

  ExampleWithSources._(this.id, this.files);

  factory ExampleWithSources.fromJson(Map<String, Object?> json) {
    return ExampleWithSources._(
        json['id'] as String,
        (json['files'] as List).cast<Map<String, Object?>>().map(SourceFile.fromJson).toList(),
    );
  }
}

class SourceFile {
  final String name;
  final String contents;

  SourceFile._(this.name, this.contents);

  factory SourceFile.fromJson(Map<String, Object?> json) {
    return SourceFile._(
        json['name'] as String,
        json['contents'] as String,
    );
  }
}

Future<List<ExampleWithSources>> loadSources() async {
  final raw = json.decode(await HttpRequest.getString('sources.json'));
  return (raw as List).cast<Map<String, Object?>>().map(ExampleWithSources.fromJson).toList();
}
</script>

<style>
  h4 {
    margin-bottom: 1em;
    margin-top: 2em;
  }

  code {
    min-width: 100%;
  }
</style>

<h2>Sources</h2>

{#if current.files.isNotEmpty }
  {#await sources from currentSources}
    {#if sources.hasData}
      {#for source in sources.data?.files ?? const []}
        <h4>{source.name}</h4>
        <code>
          <pre>{source.contents}</pre>
        </code>
      {/for}
    {:else}
      <i>Loading</i>
    {/if}
  {/await}
{:else}
No sources are available for this example.
{/if}
