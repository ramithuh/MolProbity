# Welcome to MolProbity!!

This is a fork of MolProbity optimized for modern systems (Ubuntu 24.04+) and featuring a critical fix for a long-standing Phenix buffer overflow bug.

---

# MolProbity Installation Guide (Developer Build)

**System:** Ubuntu 24.04 (Noble Numbat)  
**Python Version:** 3.10 (Required for modern syntax usage)  
**Method:** Source Bootstrap with C++ Security Patch



## 1. Prepare the Workspace

Start with a clean directory to avoid environment conflicts.

```bash
mkdir ~/molprobity_work
cd ~/molprobity_work
```

## 2. Build MolProbity & Fix Buffer Overflow

On modern Linux systems (Ubuntu 24+), a bug in the Phenix C++ source causes a `buffer overflow detected` crash due to `_FORTIFY_SOURCE` protections. 

We resolve this by patching the source code **after** downloading but **before** compiling.

```bash
# 1. Download the build script
wget https://raw.githubusercontent.com/cctbx/cctbx_project/master/libtbx/auto_build/bootstrap.py

# 2. Download the source code ONLY
python bootstrap.py --builder=molprobity --python=310 --download-only

# 3. APPLY THE CLEAN C++ FIX
# This patches a hardcoded 640-byte size argument for an 81-byte buffer
sed -i 's/std::snprintf(r, 640U/std::snprintf(r, 15U/g' modules/cctbx_project/iotbx/pdb/hierarchy.cpp

# 4. Run the full build (Base + Build)
python bootstrap.py --builder=molprobity --python=310 --nproc=4 base build
```

*Note: The compilation process takes 20-40 minutes.*

## 3. Activate and Configure

Once the build finishes, load the environment variables and run the MolProbity setup.

```bash
# 1. Source the environment (This activates the internal Conda env)
source build/setpaths.sh

# 2. Enter the MolProbity directory
cd molprobity

# 3. Run the configuration script
./setup.sh
```

* **Webserver User:** When prompted, press `Enter` (default to current user) if running locally.

## 4. (Important) Fix Binary Permissions

The contact-dot calculator (`probe`) often needs explicit executable permissions after the build.

```bash
chmod +x ../build/bin/phenix.probe
```

## 5. Run the Server

Use the built-in PHP development server for local testing.

```bash
# Ensure you are inside the 'molprobity' folder
php -S localhost:8601
```

Access the site at: **[http://localhost:8601/public_html/index.php](http://localhost:8601/public_html/index.php)**

---

### Critical Bug Fix: Phenix Buffer Overflow
This fork includes documentation and scripts to resolve a specific crash in the Phenix C++ tools (`clashscore`, `rotalyze`, `ramalyze`) encountered on systems with GLIBC 2.39+. 

**Symptoms Fixed:** 
- `*** buffer overflow detected ***: terminated` errors in CLI.
- Silent failures in the Web UI resulting in "0.00" scores or empty clash lists.

The fix (Stage 3 above) patches the `iotbx::pdb::hierarchy::atom::format_atom_record` function to use conservative buffer limits (15 bytes for float fields), allowing Phenix to run safely under modern security policies.

---

### Maintenance & Troubleshooting

#### Why was my last build so fast?
If you are rebuilding, Phenix uses an **incremental build system**. It detects that only a few files changed (like our C++ patch) and only recompiles those specific parts instead of the whole suite. 

#### How to "Factory Reset" (Full Clean Build)
If you run into strange errors and want to start truly from scratch:
```bash
# 1. Remove everything EXCEPT the MolProbity/ directory
rm -rf build/ conda_base/ modules/ bootstrap.py

# 2. Re-run the installation from Step 3 above
```

#### How to run an Incremental Update
If you just want to refresh the build or apply a small code change:
```bash
python bootstrap.py --builder=molprobity --python=310 --nproc=4 base build
```

---
*For historical installation notes and Apache/PHP 5.6 configuration, see the [legacy documentation wiki](doc/legacy_notes.md).*
