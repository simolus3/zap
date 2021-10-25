<script>
  String? currentUser = null;

  void logIn() => currentUser = 'Simon';
  void logOut() => currentUser = null;
</script>

{#if currentUser != null }
  Hi {currentUser}!
  <button on:click={logOut}>
    Log out
  </button>
{:else}
  <button on:click={logIn}>
  
    Log in
  </button>
{/if}

