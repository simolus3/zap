<script>
  const potentialQuestions = [
    'What is that beautiful house?',
    'Where does that highway go to?',
    'Am I right? Am I wrong?',
    'My God! What have I done?',
  ];
</script>

<h1>Potential questions</h1>

<ul>
  {#for question in potentialQuestions}
    <li>{question}</li>
  {/for}
</ul>

