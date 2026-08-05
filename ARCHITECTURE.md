# Arc-Vault Architecture
```mermaid
graph TD
    User -->|Connect| Frontend
    Frontend -->|API| Circle[Circle SDK]
    Circle -->|Sign| Vault[Arc-Vault Contract]
    Vault -->|Yield| Strategy[Yield Strategy]
    Strategy -->|Repay| Vault

