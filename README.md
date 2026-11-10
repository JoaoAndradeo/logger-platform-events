# Logger com Platform Events

Logger para Apex e Flow. Os logs são gravados mesmo quando a transação de negócio faz rollback. Há uma tela em LWC para filtrar e paginar os registros.

## Como funciona

Se a transação de negócio dá rollback, qualquer registro gravado nela também é desfeito. Por isso o Logger não grava direto no `Log__c`:

1. `Logger.error(...)` guarda a entrada em memória. Nada é gravado nesse momento.
2. `Logger.flush()` publica a entrada como evento (`Log_Event__e`, com *Publish Immediately*).
3. O `LogEventTrigger` recebe o evento e grava o `Log__c` em outra transação.

Detalhes sobre rollback e limites: [docs/rollback.md](docs/rollback.md).

## Por que importa

Quando uma transação falha, todo `insert` feito nela também é desfeito, inclusive o de log. Sem um mecanismo à parte, o erro acontece e não fica nenhum registro dele.

## Ganho

- Registro de falhas que um `insert` direto perderia em rollback.
- Um único ponto de log para Apex e Flow. O nível mínimo muda em `Logger_Settings__mdt`, sem deploy.
- Investigação mais rápida: a tela filtra por nível e origem, sem abrir o debug log de cada execução.

## Uso no Apex

```apex
public with sharing class ContratoService {
    public static void ativar(Id contratoId) {
        Savepoint sp = Database.setSavepoint();
        try {
            update new Contrato__c(Id = contratoId, Status__c = 'Ativo');
        } catch (Exception e) {
            Database.rollback(sp);
            Logger.error('ContratoService.ativar', e, contratoId);
        } finally {
            Logger.flush();
        }
    }
}
```

Métodos: `Logger.debug`, `Logger.info`, `Logger.warn` e `Logger.error`. Entradas abaixo do nível mínimo de `Logger_Settings__mdt` são descartadas.

## Uso no Flow

Use a ação **Registrar log**. Campos: nível (DEBUG, INFO, WARN ou ERROR), origem, mensagem e ID do registro (opcional). Nível inválido vira INFO.

## Consulta

Atribua a permission set **Logger Viewer** ao usuário e adicione o componente `logViewer` a uma página. A App Page **Logs da Aplicação** já tem o componente.

## Deploy

Pré-requisitos: Salesforce CLI e uma Developer Edition.

```bash
sf org login web --alias DevEd --set-default --instance-url https://login.salesforce.com
sf project deploy start --source-dir force-app --target-org DevEd --test-level RunLocalTests
sf org assign permset --name Logger_Admin --target-org DevEd
```

## Testes

- Apex: testes em `LoggerTest`, `LogEventHandlerTest`, `LoggerInvocableTest` e `LogViewerControllerTest`.
- Jest (LWC `logViewer`): 7 testes.

## Limitações

- Se uma exceção não tratada derrubar a transação antes do `flush()`, o log se perde. O `try/catch` com `finally` no ponto de entrada evita isso.
- Não há política de retenção: os logs ficam na org até serem apagados.
- A publicação usa *Publish Immediately*. Esse tipo de evento depende do Standard Volume Platform Event, cuja aposentadoria ainda não foi confirmada pela documentação oficial.
