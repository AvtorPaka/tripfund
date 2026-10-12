# TripFund

Контракт для организации целевых сборов в ERC-20 токене по модели "all-or-nothing crowdfunding": при достижении цели к сроку средства получает организатор, иначе участники забирают свои взносы.

[Спецификация задания](./spec/spec.pdf)

- [Версии](#версии)
- [Установка](#установка)
- [Сборка и тесты](#сборка-и-тесты)
- [Пример: approve + взнос](#пример-approve--взнос)
- [Тесты-кейсы](#тесты-кейсы)
    - [Взносы](#взносы-tripfundcontributetest)
    - [Выплаты](#выплаты-tripfundpayouttest)
    - [Прямые переводы](#прямые-переводы-tripfunddirecttransfertest)

## Версии

[foundry.lock](./foundry.lock)

| Компонент | Версия |
| --- | --- |
| Foundry (forge) | 1.8.5 |
| Solidity | 0.8.37 |
| OpenZeppelin Contracts | 5.7.0 (`lib/openzeppelin-contracts`) |
| forge-std | 1.17.0 (`lib/forge-std`) |

## Установка

[Установка Foundry](https://www.getfoundry.sh/introduction/installation)

```sh
git clone --recursive https://github.com/AvtorPaka/tripfund.git tripfund
cd tripfund
```

Если склонирован без `--recursive`:

```sh
forge install
```

## Сборка и тесты

```sh
forge clean && forge build && forge test
```

Результаты сборки и тестов доступны в запуске CI по последнему комиту

## Пример: approve + взнос

```solidity
// разрешаем контракту списать 10 токенов
token.approve(address(fund), 10e18);

// контракт забирает их через safeTransferFrom
fund.contribute(10e18);
```

После дедлайна при достигнутой цели организатор вызывает `fund.withdraw()`, иначе каждый участник вызывает `fund.refund()`.

## Тесты-кейсы

###  Взносы: `TripFundContributeTest`

| Тест | Пункт | Кейс |
| --- | --- | --- |
| `test_Contribute_TwoContributorsWithRepeatedContributions` | 6 | два участника, повторный взнос суммируется, учёт и токенные балансы |
| `test_RevertWhen_ContributeZeroAmount` | 6 | нулевая сумма — откат без изменений учёта и балансов |
| `test_RevertWhen_ContributeWithInsufficientBalance` | 6 | недостаточный баланс — откат без изменений учёта и балансов |
| `test_RevertWhen_ContributeWithInsufficientAllowance` | 6 | недостаточный allowance — откат без изменений учёта и балансов |
| `test_Contribute_OneSecondBeforeDeadline` | 7 | взнос за 1 секунду до дедлайна проходит |
| `test_RevertWhen_ContributeExactlyAtDeadline` | 7 | взнос ровно в дедлайн отклоняется |

### Выплаты: `TripFundPayoutTest`

| Тест | Пункт | Кейс |
| --- | --- | --- |
| `test_RevertWhen_PayoutBeforeDeadlineEvenIfGoalReached` | 7 | до дедлайна `withdraw` и `refund` запрещены даже при достигнутой цели |
| `test_Withdraw_WhenGoalReachedExactly` | 8 | сумма ровно `goal` — организатор получает её, баланс контракта 0 |
| `test_Withdraw_WhenGoalExceeded` | 8 | сумма выше `goal` — организатор получает всю сумму |
| `test_RevertWhen_WithdrawByNonOrganizer` | 8 | запрет чужого вывода |
| `test_RevertWhen_WithdrawTwice` | 8 | запрет повторного вывода |
| `test_RevertWhen_WithdrawWhenGoalNotReached` | 8 | запрет вывода при недостигнутой цели (неверный исход) |
| `test_RevertWhen_RefundWhenGoalReached` | 8 | запрет возврата при достигнутой цели (неверный исход) |
| `test_Refund_IndependentRefundsWhenGoalNotReached` | 8 | сумма ниже `goal` — каждый вкладчик независимо возвращает свой полный вклад |
| `test_RevertWhen_RefundTwice` | 8 | запрет повторного возврата |

### Прямые переводы: `TripFundDirectTransferTest`

| Тест | Пункт | Кейс |
| --- | --- | --- |
| `test_DirectTransfer_DoesNotChangeTotalRaised` | 9 | прямой перевод токенов не меняет `totalRaised` |
| `test_DirectTransfer_RemainsAfterWithdraw` | 9 | после вывода организатором прямой перевод остаётся в контракте |
| `test_DirectTransfer_RemainsAfterAllRefunds` | 9 | после всех возвратов прямой перевод остаётся в контракте |
