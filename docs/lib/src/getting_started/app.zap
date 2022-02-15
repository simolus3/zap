<script>
  import 'template.dart';
  import 'utils.dart';

  String? projectName;
  var isValidProjectName = true;

  $: isValidProjectName = projectName == null || projectName!.isEmpty || isValidPackageName(projectName!);

  void download() {
    downloadExample(projectName ?? 'zap_playground');
  }
</script>

<style>
  span {
    color: var(--form-element-invalid-border-color);
  }

  .invisible {
    visibility: hidden;
  }
</style>

<article>
  <header>
    <hgroup>
      <h1>Getting started</h1>
      <h3>Use the template with zap fully set up.</h3>
    </hgroup>
  </header>
  <form>
    <label for="project-name">
      Package name for your project
      <input bind:value={projectName} type="text" id="project-name" placeholder="Project name" aria-invalid={!isValidProjectName}>
    </label>
    <span class="{isValidProjectName ? 'invisible' : ''}">
      The project name must be a valid Dart package name (lowercase_with_underscores, not a reserved keyword).
    </span>
  </form>
  <footer>
    <button on:click={download}>Download project</button>

    <small>For more information on zap, see the <a href="../docs/">documentation</a>.</small>
  </footer>
</article>
