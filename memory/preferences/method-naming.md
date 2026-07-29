# Leave stopwords out of method names

Skip `a`, `an`, `the` and `to` when naming methods — most of all test methods,
where the temptation to write a sentence is strongest.

`testBareAnswerBecomesParagraph`, not `testBareAnswerBecomesAParagraph`.
`testReadReturnsCsv`, not `testReadReturnsTheCsv`.
`testColumnMapping`, not `testColumnsMapToQuestionAndAnswer`.

**Why:** it reads better — the articles carry nothing a reader needs — and an
article immediately before a capitalised word also breaks the Drupal coding
standard. `Drupal.NamingConventions.ValidFunctionName` sees the `A` in
`BecomesAParagraph` as the start of a run of capitals and fails the method with
"is not in lowerCamel format". The same applies to `AnItem`, `ACsv` and so on,
so the style rule and the sniff agree.

**How to apply:** name for the subject and the behaviour, nothing else. If a
name still needs an article to make sense, it is usually describing two things
and wants splitting — or it wants a shorter noun phrase (`testColumnMapping`)
with the detail left to the docblock, which is where the sentence belongs.
