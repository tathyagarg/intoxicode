<script lang="ts">
  import { marked } from "marked";
  let { data } = $props();

  $effect(() => {
    if (data.title) document.title = data.title;
  });
</script>

<div class="p-4 prose prose-awesome font-sans">
  {@html marked(data.content)}
</div>
