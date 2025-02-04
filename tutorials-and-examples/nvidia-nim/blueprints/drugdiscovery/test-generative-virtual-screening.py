import requests

AF2_HOST = "http://localhost:8010"
MOLMIM_HOST = "http://localhost:8011"
DIFFDOCK_HOST = "http://localhost:8012"


def check_readiness(service_name, url):
    try:
        response = requests.get(url)
        response.raise_for_status()  # Raise an exception for bad status codes
        print(f"{service_name} readiness check successful at {url}.")
        return True
    except requests.exceptions.RequestException as e:
        print(f"{service_name} readiness check failed: {e}")
        return False


check_readiness("AlphaFold2", f"{AF2_HOST}/v1/health/ready")
check_readiness("MolMIM", f"{MOLMIM_HOST}/v1/health/ready")
check_readiness("DiffDock", f"{DIFFDOCK_HOST}/v1/health/ready")


## AlphaFold2 NIM
protein_sequence = "MVPSAGQLALFALGIVLAACQALENSTSPLSADPPVAAAVVSHFNDCPDSHTQFCFHGTCRFLVQEDKPACVCHSGYVGARCEHADLLAVVAASQKKQAITALVVVSIVALAVLIITCVLIHCCQVRKHCEWCRALICRHEKPSALLKGRTACCHSETVV"

print("Protein folding with AlphaFold2...")  # Progress update
try:
    af2_response = requests.post(
        f"{AF2_HOST}/protein-structure/alphafold2/predict-structure-from-sequence",
        json={
            "sequence": protein_sequence,
            "databases": ["small_bfd"],
        },
    )
    af2_response.raise_for_status()  # Check for HTTP errors
    folded_protein = af2_response.json()[0]
    print("Protein folding successfully.")  # Progress update

except requests.exceptions.RequestException as e:
    print(f"AlphaFold2 request failed: {e}")
    exit(1)  # Exit if AlphaFold2 fails
except IndexError:
    print("Invalid response from AlphaFold2 (missing structure).")
    exit(1)

## MolMIM NIM
molecule = "CC1(C2C1C(N(C2)C(=O)C(C(C)(C)C)NC(=O)C(F)(F)F)C(=O)NC(CC3CCNC3=O)C#N)C"

print("Generating molecules with MolMIM...")  # Progress update
try:
    molmim_response = requests.post(
        f"{MOLMIM_HOST}/generate",
        json={
            "smi": molecule,
            "num_molecules": 5,
            "algorithm": "CMA-ES",
            "property_name": "QED",
            "min_similarity": 0.7,  # Ignored if algorithm is not "CMA-ES".
            "iterations": 10,
        },
    )
    molmim_response.raise_for_status()  # Check for HTTP errors
    molmim_response = molmim_response.json()

    # Validate the response (check if 'generated' key exists and is a list)
    if "generated" not in molmim_response or not isinstance(
        molmim_response["generated"], list
    ):
        raise ValueError("Invalid response format from MolMIM")

    generated_ligands = "\n".join([v["smiles"] for v in molmim_response["generated"]])
    print(generated_ligands)
    print("Molecular generation successfully.")  # Progress update

except requests.exceptions.RequestException as e:
    print(f"MolMIM request failed: {e}")
    exit(1)  # Exit if MolMIM fails
except ValueError as e:
    print(f"Error processing MolMIM response: {e}")
    exit(1)

## DiffDock NIM
diffdock_response = requests.post(
    f"{DIFFDOCK_HOST}/molecular-docking/diffdock/generate",
    json={
        "protein": folded_protein,
        "ligand": generated_ligands,
        "ligand_file_type": "txt",
        "num_poses": 10,
        "time_divisions": 20,
        "num_steps": 18,
    },
).json()

print("Protein-ligand docking with DiffDock...")  # Progress update

# Example assuming diffdock_response["ligand_positions"] is a list of lists.
try:
    for i in range(len(diffdock_response["ligand_positions"])):
        print("*" * 80)
        print(f"Docking result {i+1}:")  # More descriptive output
        print(
            diffdock_response["ligand_positions"][i][0]
        )  # Print the first pose for now.  Handle multiple poses if needed.
    print("Protein-ligand docking successful")  # Progress update

except requests.exceptions.RequestException as e:
    print(f"Error processing DiffDock results: Invalid response format: {e}")
    exit(1)  # Exit if MolMIM fails
