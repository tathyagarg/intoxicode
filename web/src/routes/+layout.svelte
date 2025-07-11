<script lang="ts">
  import "../app.css";

  let { children } = $props();
</script>

<div class="min-h-screen min-w-screen max-w-screen bg-base text-text">
  {@render children()}
  <div
    class="text-sm text-subtext0 p-4 bg-crust flex justify-center gap-8 items-center"
  >
    <div class="flex gap-2 items-center">
      <span>Powered by</span><img
        src="/svelte.svg"
        alt="SvelteKit"
        class="h-6"
      />
    </div>
    <div>
      Inspired by <a href="https://github.com/cyteon/modu" class="text-blue"
        >Modu</a
      >
    </div>
  </div>
</div>
