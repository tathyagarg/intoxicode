<script lang="ts">
  export let name: string;
  export let file: string;
</script>

<a href={file} download="intoxicode">
  <div
    class="bg-surface0 shadow-2xl p-4 text-center rounded-md h-20 leading-12"
  >
    {name}
  </div>
</a>
