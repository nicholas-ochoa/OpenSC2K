//! The load order of the mods: the dependencies of a mod load before it, and
//! otherwise the ids decide.

use super::manifest::Manifest;

/// A found mod: its manifest and the name of its folder.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Found {
    pub folder: String,
    pub manifest: Manifest,
}

/// Give a second folder with the same id an error, then order the mods. The
/// mods are in folder name order.
pub fn catalog(mut found: Vec<Found>) -> Vec<Found> {
    let mut first: Vec<(String, String)> = Vec::new();

    for item in &mut found {
        let id = item.manifest.id.clone();

        match first.iter().find(|(known, _)| *known == id) {
            Some((_, folder)) => {
                item.manifest.error = format!("The mod in {folder} already has the id {id}.")
            }
            None if item.manifest.error.is_empty() => first.push((id, item.folder.clone())),
            None => {}
        }
    }

    load_order(found)
}

/// The mods with each dependency before the mods that need it, else by id. A
/// mod in a dependency cycle gets an error. A missing dependency does not
/// change the order; the mod then waits for it.
pub fn load_order(mut mods: Vec<Found>) -> Vec<Found> {
    mods.sort_by(|a, b| (&a.manifest.id, &a.folder).cmp(&(&b.manifest.id, &b.folder)));
    let mut by_id: Vec<(String, usize)> = Vec::new();

    for (index, item) in mods.iter().enumerate() {
        if item.manifest.error.is_empty() && !by_id.iter().any(|(id, _)| *id == item.manifest.id) {
            by_id.push((item.manifest.id.clone(), index));
        }
    }

    // 1 while the mod is on the path of the search, 2 when it is placed
    let mut marks = vec![0u8; mods.len()];
    let mut order = Vec::new();

    for index in 0..mods.len() {
        visit(index, &mut mods, &by_id, &mut marks, &mut order);
    }

    let mut slots: Vec<Option<Found>> = mods.into_iter().map(Some).collect();

    order
        .into_iter()
        .filter_map(|index| slots[index].take())
        .collect()
}

fn visit(
    index: usize,
    mods: &mut [Found],
    by_id: &[(String, usize)],
    marks: &mut [u8],
    order: &mut Vec<usize>,
) -> bool {
    match marks[index] {
        2 => return true,
        1 => return false,
        _ => {}
    }

    marks[index] = 1;
    let mut acyclic = true;

    if mods[index].manifest.error.is_empty() {
        for dependency in mods[index].manifest.dependencies.clone() {
            if let Some(&(_, target)) = by_id.iter().find(|(id, _)| *id == dependency)
                && !visit(target, mods, by_id, marks, order)
            {
                acyclic = false;
            }
        }
    }

    let manifest = &mut mods[index].manifest;

    if !acyclic && manifest.error.is_empty() {
        manifest.error = format!(
            "The dependencies of the mod make a cycle: {}.",
            manifest.dependencies.join(", ")
        );
    }

    marks[index] = 2;
    order.push(index);

    acyclic
}

#[cfg(test)]
mod tests {
    use super::*;

    fn found(folder: &str, id: &str, dependencies: &[&str]) -> Found {
        Found {
            folder: folder.into(),
            manifest: Manifest {
                id: id.into(),
                dependencies: dependencies.iter().map(|id| id.to_string()).collect(),
                ..Manifest::default()
            },
        }
    }

    #[test]
    fn dependencies_load_first_and_cycles_fail() {
        let order = catalog(vec![
            found("a", "a", &["c"]),
            found("b", "b", &[]),
            found("c", "c", &[]),
            found("d", "a", &[]),
        ]);
        let ids: Vec<(&str, &str)> = order
            .iter()
            .map(|item| (item.folder.as_str(), item.manifest.error.as_str()))
            .collect();
        assert_eq!(
            ids,
            vec![
                ("c", ""),
                ("a", ""),
                ("d", "The mod in a already has the id a."),
                ("b", "")
            ]
        );

        let cycle = load_order(vec![found("x", "x", &["y"]), found("y", "y", &["x"])]);
        assert!(
            cycle
                .iter()
                .all(|item| item.manifest.error.contains("make a cycle"))
        );
    }
}
