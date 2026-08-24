# Prontidão de release

[English](RELEASE_READINESS.md)

## Objetivo

Este checklist prepara um candidato revisado sem autorizar tag, GitHub Release,
mudança de visibilidade, merge ou publicação. Mudanças de produto permanecem na
fonte privada autoritativa até serem sanitizadas e sincronizadas para um checkout
standalone limpo.

## Decisão da versão atual

`v1.0.0` é uma tag anotada existente. A `main` contém correções funcionais e
documentais posteriores à tag na seção `Unreleased`. `VERSION` permanece em
`1.0.0` até que o proprietário escolha explicitamente preparar ou não `1.0.1`.

Não mova `v1.0.0` nem reescreva seu histórico. Se `1.0.1` for aprovada, atualize
`VERSION` e feche a seção do changelog em uma única mudança revisada de preparação;
crie a tag somente depois que o commit exato sincronizado passar por todos os
gates.

## Gates offline

Execute sem credenciais AWS:

```bash
make test
make ci
```

O CI deve aprovar testes, sintaxe Bash, ShellCheck, compilação Python, JSON,
formatação Terraform, proibição de apply, isolamento de credenciais, padrões de
arquivos rastreados e segredos, links Markdown, metadados de release, smoke test
de checkout limpo e whitespace do Git. Registre a contagem exata de testes; nunca
reutilize ou deduza resultados antigos.

## Sanitização e validação standalone

1. Execute a auditoria com a denylist privada sobre a fonte publicável e todo o
   histórico standalone alcançável.
2. Sincronize pelo script privado de publicação revisado.
3. Revise cada caminho alterado e confirme a ausência de documentação privada e
   dados de runtime.
4. Valide em um checkout standalone limpo, sem configuração AWS.
5. Confirme o commit standalone exato e uma execução bem-sucedida do CI.
6. Revise o histórico e os logs acessíveis do Actions antes de mudar a
   visibilidade.

Terraform gerado, state, planos, relatórios, inventários, pacotes Lambda, valores
SSM, credenciais, configuração local e identificadores privados nunca são
artefatos de release.

## Limite da aceitação AWS real

O CI offline não comprova descoberta real, comportamento do provider, paridade de
imports ou limpeza. Repita a aceitação controlada na AWS somente quando a mudança
afetar essas áreas e o proprietário autorizar separadamente conta, região, acesso
temporário, criação de recursos e limpeza. O `tf-importer` nunca executa
`terraform apply`.

Um plano aceito contém somente imports e zero ações de add, change ou destroy.

## Gate final de aprovação

Pare depois de apresentar diff revisado, evidências exatas de validação, riscos
restantes e a decisão entre `1.0.0` e `1.0.1`. O proprietário deve aprovar
separadamente cada merge, tag, GitHub Release, mudança de visibilidade ou anúncio
externo.
