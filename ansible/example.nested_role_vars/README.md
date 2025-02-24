# Ansible Nested Role Variables Example

This example demonstrates how variables from `role1` can be injected into called roles, which is not possible by default in Ansible. The variable precedence is as follows: `host_vars` < `group_vars` < `role1_defaults` < `role2_defaults`.

## File Structure

## Playbook Execution Output

The following is the output of running the `role_test.yml` playbook, as recorded in `role_test.log`:

```
PLAY [localhost] ***************************************************************

TASK [role1 : set_fact] ********************************************************
ok: [localhost]

TASK [role1 : set pass_vars into current context] ******************************
ok: [localhost] => (item={'key': 'var1', 'value': 'host_var'})
ok: [localhost] => (item={'key': 'var2', 'value': 'role1_defaults'})

TASK [role1 : debug] ***********************************************************
ok: [localhost] => 
  pass_vars:
    var1: host_var
    var2: role1_defaults

TASK [include_role : role2] ****************************************************
included: role2 for localhost

TASK [role2 : debug] ***********************************************************
ok: [localhost] => 
  var1: host_var

TASK [role2 : debug] ***********************************************************
ok: [localhost] => 
  var2: role1_defaults

TASK [role2 : debug] ***********************************************************
ok: [localhost] => 
  var3: role2_defaults

PLAY RECAP *********************************************************************
localhost                  : ok=7    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
```

### Explanation

- **ariable Precedence**: The variables are set in the following order of precedence: `host_vars` < `role1_defaults` < `role2_defaults`.
- **role1**: Sets `var1` to `host_var` and `var2` to `role1_defaults` using `set_fact`. These variables are then passed to the current context.
- **role2**: Receives the variables from `role1`. The `debug` tasks show that `var1` is set to `host_var`, `var2` is set to `role1_defaults`, and `var3` is set to `role2_defaults`.
- This demonstrates how variables can be passed from one role to another, with the final values reflecting the precedence rules.

```
ansible.nested_role_vars_example/
├── ansible.cfg
├── inventory
│   └── localhost
├── playbooks
│   ├── role_test.log
│   └── role_test.yml
├── README.md
└── roles
    ├── role1
    │   ├── defaults
    │   │   └── main.yml
    │   └── tasks
    │       └── main.yml
    └── role2
        ├── defaults
        │   └── main.yml
        └── tasks
            └── main.yml
```

## How It Works

- **role1**: Sets variables using `set_fact` and passes them to the current context.
- **role2**: Receives variables from `role1` and demonstrates their values using `debug`.

## Running the Example

To run the example, execute the following command:

```bash
ansible-playbook playbooks/role_test.yml
```

This will show how variables are passed from `role1` to `role2` and the resulting output.
