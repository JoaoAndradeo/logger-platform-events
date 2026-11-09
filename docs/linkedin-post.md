# Rascunho do post para o LinkedIn

> Escrito para: pessoas da rede no LinkedIn (desenvolvedores Salesforce).

---

Meu log sumia justamente quando eu mais precisava dele. Esse foi o ponto de partida de um projeto pessoal: um Logger para Apex e Flow que não some quando a transação dá rollback.

O problema: se a transação de negócio falha e volta atrás, o `Log__c` gravado nela também volta. O erro que você queria investigar desaparece.

A solução que usei: o código só guarda a entrada em memória. No fim, o `flush()` publica um evento (Platform Event com *Publish Immediately*), e um trigger grava o log em outra transação. O `flush()` fica no `finally`, então o log sai mesmo quando o erro é relançado.

Validei o rollback na minha org de desenvolvimento: a conta criada antes da falha foi revertida, e o log continuou lá.

Também deixei documentado o que não cobre: uma exceção não tratada que derruba a transação antes do `flush()` ainda faz o log se perder.

Código e documentação: https://github.com/JoaoGuilherme777/logger-platform-events

#Salesforce #Apex #PlatformEvents #SalesforceDeveloper
