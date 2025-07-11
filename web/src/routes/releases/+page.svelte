<script>
  import Release from "$lib/components/Release.svelte";
</script>

<div class="p-4 w-full h-full">
  <h1 class="text-2xl font-bold">Releases</h1>
  <p class="text-lg mt-2">
    The latest version of IntoxiCode is available for download below. If you
    have any issues, please raise an issue on the GitHub repository.
  </p>
  <div class="grid grid-cols-3 grid-rows-1 w-full gap-4 mt-4">
    <Release name="Windows" file="intoxicode-windows-x86_64.exe" />
    <Release name="MacOS" file="intoxicode-macos-x86_64" />
    <Release name="Linux" file="intoxicode-linux-x86_64" />
  </div>
  <img
    src="https://s3.amazonaws.com/pix.iemoji.com/images/emoji/apple/ios-12/256/tongue.png"
    alt="Tongue emoji"
    class="w-1/3 h-1/3 mx-auto mt-2"
  />
</div>
