<script lang="ts">
  let { children } = $props();

  import paths from "$lib/docs/paths";
</script>

<div class="min-h-screen min-w-screen max-w-screen flex flex-row">
  <div class="flex-1 bg-base p-4 box-border shadow-2xl">
    <div class="sticky top-2 flex flex-col gap-2 justify-center">
      <h1 class="font-bold text-2xl">Contents</h1>
      <hr />
      <ul class="mt-2">
        {#each Object.entries(paths) as [key, path]}
          <li class="border-l-2 border-surface2 pl-4 hover:border-text">
            <a
              class="block text-subtext1 text-lg hover:text-text"
              href={`/docs/${key}`}
            >
              {path.name}
            </a>
          </li>
        {/each}
      </ul>
    </div>
  </div>
  <div class="flex-[4] shadow-2xl">
    {@render children()}
  </div>
</div>
