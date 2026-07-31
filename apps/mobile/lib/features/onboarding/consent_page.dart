import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Consentimento específico para tratamento de dados infantis, antes da
/// primeira criança existir (docs/03 seção 3, passo 2; docs/10 seção 4).
///
/// O registro em `consent_records` exige uma família (FK), então é
/// persistido logo após a criação da família na etapa seguinte — mas o
/// consentimento é obtido aqui, antes de qualquer dado da criança.
class ConsentPage extends StatefulWidget {
  const ConsentPage({super.key});

  @override
  State<ConsentPage> createState() => _ConsentPageState();
}

class _ConsentPageState extends State<ConsentPage> {
  bool _agreed = false;

  static const documentVersion = '2026-07-31';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Antes de continuar')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dados da família e da criança',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Para usar o Kid\'s Task, guardamos: seu nome e e-mail; o '
                      'nome, apelido, data de nascimento e avatar da criança; '
                      'tarefas, KidsCoins, XP e progresso. Não coletamos '
                      'gênero, localização ou dados de biometria. A data de '
                      'nascimento é usada apenas para calcular idade, faixa de '
                      'apresentação e bônus de aniversário — nunca é exibida '
                      'publicamente nem enviada em notificações.\n\n'
                      'Você pode consultar, corrigir, exportar ou excluir esses '
                      'dados a qualquer momento na área "Mais > Privacidade".',
                    ),
                  ],
                ),
              ),
            ),
            CheckboxListTile(
              value: _agreed,
              onChanged: (value) => setState(() => _agreed = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'Li e concordo com o tratamento de dados descrito acima',
              ),
            ),
            FilledButton(
              onPressed: _agreed
                  ? () => context.go(
                      '/onboarding/family',
                      extra: {'documentVersion': documentVersion},
                    )
                  : null,
              child: const Text('Continuar'),
            ),
          ],
        ),
      ),
    );
  }
}
