<script lang="ts">
  let { children } = $props();

  import paths from "$lib/docs/paths";
</script>

<div class="min-h-screen min-w-screen max-w-screen flex flex-row">
  <div class="flex-1 bg-mantle p-4 box-border">
    {#each Object.entries(paths) as [key, path]}
      <a class="block text-text hover:text-text-hover" href={`/docs/${key}`}>
        {path.name}
      </a>
    {/each}
  </div>
  <div class="flex-[4]">
    {@render children()}
  </div>
</div>
