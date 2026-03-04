const List<Map<String, dynamic>> settleTools = [
  {
    'name': 'add_expense',
    'description':
        'Add a new expense to the user\'s Settle account. '
        'Use this when the user describes spending money, buying something, '
        'paying for something, or mentions an amount with context. '
        'Infer the tag from context. Default currency is SGD unless specified. '
        'If the user mentions someone owes them money or they\'re splitting, '
        'populate the split fields.',
    'input_schema': {
      'type': 'object',
      'properties': {
        'amount': {
          'type': 'number',
          'description': 'The total expense amount (before splitting)',
        },
        'name': {
          'type': 'string',
          'description':
              'Short description of the expense, e.g. "Coffee", "Grab to airport"',
        },
        'tag': {
          'type': 'string',
          'enum': [
            'Food',
            'Transport',
            'Shopping',
            'Entertainment',
            'Bills',
            'Health',
            'Travel',
            'Other',
          ],
          'description': 'Category tag. Infer from context.',
        },
        'currency': {
          'type': 'string',
          'description':
              '3-letter currency code, e.g. SGD, USD, GBP. Default: SGD',
        },
        'date': {
          'type': 'string',
          'description':
              'ISO 8601 date string, e.g. 2025-03-04. Default: today.',
        },
        'splitWith': {
          'type': 'array',
          'items': {'type': 'string'},
          'description': 'List of usernames (without @) to split with',
        },
        'splitMode': {
          'type': 'string',
          'enum': ['equal', 'custom', 'omit'],
          'description':
              'How to split. "equal" divides evenly. Only set if splitting.',
        },
        'customAmounts': {
          'type': 'object',
          'description': 'Map of username → amount owed, for custom splits',
        },
        'omittedUsernames': {
          'type': 'array',
          'items': {'type': 'string'},
          'description': 'Usernames excluded from the split',
        },
      },
      'required': ['amount', 'name', 'tag', 'currency', 'date'],
    },
  },

  {
    'name': 'add_savings_contribution',
    'description':
        'Add an amount to an existing savings goal. '
        'Use when the user says they saved money, put money aside, or contributed to a goal.',
    'input_schema': {
      'type': 'object',
      'properties': {
        'goalName': {
          'type': 'string',
          'description': 'Name of the savings goal (fuzzy match OK)',
        },
        'amount': {
          'type': 'number',
          'description': 'Amount being added to the goal',
        },
        'currency': {
          'type': 'string',
          'description': 'Currency code. Default: SGD',
        },
      },
      'required': ['goalName', 'amount', 'currency'],
    },
  },

  {
    'name': 'get_financial_summary',
    'description':
        'Retrieve the user\'s spending summary and expense list for a time period. '
        'Use this when the user asks about their spending, wants analysis, '
        'or needs data to answer a financial question.',
    'input_schema': {
      'type': 'object',
      'properties': {
        'period': {
          'type': 'string',
          'enum': ['today', 'week', 'month', 'last_month', 'custom'],
          'description': 'Time period to query',
        },
        'startDate': {
          'type': 'string',
          'description': 'ISO date, required if period is "custom"',
        },
        'endDate': {
          'type': 'string',
          'description': 'ISO date, required if period is "custom"',
        },
        'groupBy': {
          'type': 'string',
          'enum': ['tag', 'day', 'none'],
          'description': 'How to aggregate results',
        },
      },
      'required': ['period'],
    },
  },
];
