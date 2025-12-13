# Post-Fire Decision Support: Our Approach

A toolbox connecting disturbance assessment, vegetation modeling, and resource planning for land managers.

---

## The Challenge

After a wildfire, land managers face a "decision crush": they need to quickly assess damage, predict what will happen next, and decide where to intervene—all while operating under budget constraints, time pressure, and deep uncertainty about treatment effectiveness.

Our toolbox addresses four sequential questions that every manager must answer:

| Question | Tool | Status |
| :---- | :---- | :---- |
| **What happened?** | Disturbance Severity | In **beta**, with *Vegetation Impacts* provided for Mojave National Preserve and Joshua Tree National Park |
| **What is going to happen?** | Vegetation Modeling (with [`josh`](http://joshsim.org)) | `josh` core engine in **beta**: model development ongoing |
| **What should we do?** | Resource Optimization | In design |
| **Did it work?** | ? | Long-term; approach in development |

---

## Fire Severity Assessment

### Why we're building it

Federal agencies produce burn severity maps after major fires, but these typically arrive weeks after the event and use calibrations designed for high-biomass forests. In low-biomass environments like the Mojave Desert, standard spectral indices underestimate severity because there's less vegetation signal to begin with.

Our partners needed severity assessments that were: (1) faster—available within days, not weeks; (2) tuned for their landscape; and (3) directly linked to vegetation community data so they could immediately report impacts when applying for recovery funding.

### What it does

The Fire Severity Tool uses Sentinel-2 satellite imagery to generate burn severity maps by comparing pre-fire and post-fire conditions. It overlays severity data on park vegetation maps to produce immediate impact summaries by vegetation community—the format managers need for grant applications and internal reporting.

Standard burn severity assessments often use differenced Normalized Burn Ratio (dNBR), which measures the absolute difference in healthy vegetation signal before and after a fire. This works well in forests, but in low-biomass environments like the Mojave Desert, dNBR is biased low—even a fire that completely consumes all vegetation produces a smaller absolute difference than a moderate fire in a high-biomass forest, simply because there was less vegetation to begin with. Our tool provides Relativized Burn Ratio (RBR), which scales fire intensity to pre-fire conditions at each location, so equivalent ecological damage produces equivalent severity values regardless of landscape type.

The tool outputs cloud-optimized GeoTIFFs that can be used standalone or passed directly into the vegetation modeling step.

### What it does and doesn't do

**It does:**

- Generate severity maps within days of a fire, given cloud-free imagery  
- Provide relative metrics (RBR) appropriate for low-biomass environments, alongside absolute metrics (dNBR)  
- Link severity to vegetation community data for impact reporting  
- Provide downloadable products (GeoTIFFs, summary tables) for downstream use

**It doesn't:**

- Replace on-the-ground severity assessments (which remain important for validation)  
- Introduce novel remote sensing methods—we use established indices, selected for context  
- Work well in heavily clouded conditions or for very small fires

### Our design philosophy

The spectral indices we use are not novel—dNBR and RBR have been standard tools for years. What we've done is make the *right* products accessible on demand: our partners were receiving dNBR from federal agencies, but RBR is more appropriate for their landscape. By generating these ourselves and integrating them with vegetation data, we deliver useful assessments faster. This reflects our broader approach: responsiveness to partner needs over methodological novelty, while remaining scientifically rigorous.

---

## Vegetation Modeling with josh

### Why we're building it

After a fire, managers need to anticipate what will happen next: Will native vegetation recover on its own? Will invasive grasses take over? How do different climate futures change the picture? And critically—how might different management interventions alter these trajectories?

Traditionally, ecologists approach this with empirical models—regressions trained on observed data. But empirical models need data that are both spatially and temporally rich at the taxonomic resolution you care about. In practice, we almost never have this. What we typically see is either:

- **Vegetation maps**: Spatially comprehensive but representing a single point in time  
- **Long-term monitoring plots**: Temporally rich but covering small areas

To model something like Joshua tree recovery (not just "desert shrub"), we would need decades of repeated measurements across the landscape—data that don't exist and likely never will.

### What it does

Rather than training models on insufficient data, we take a "bottom-up" approach. We build vegetation models from first principles using life history data from the ecological literature: germination rates, growth curves, mortality schedules, competitive interactions, and responses to fire, drought, and management interventions.

[josh](https://joshsim.org) is an open-source, spatially explicit simulation engine that makes this process-based approach accessible. It provides a domain-specific language for specifying organisms, their life stages, demographic rates, and interactions with environmental conditions. Models run in the browser for small simulations or scale to cloud computing for landscape-level analysis.

In the context of our toolbox, a josh model must be parameterized and validated *before* a fire event occurs. The model knows how to respond to fire effects (mortality, reduced competition, seed bank impacts) and management interventions (seeding, planting, invasive removal), but these responses need to be built in ahead of time. The payoff is that when a fire does occur, the toolbox can automatically load the severity raster into the pre-built model and generate projections rapidly—managers don't need to interact with josh directly.

### What it does and doesn't do

**It does:**

- Simulate multi-decadal vegetation dynamics based on ecological processes  
- Incorporate fire severity as an initial condition affecting seed banks, mortality, and competition  
- Allow comparison of passive recovery vs. management interventions vs. different climate futures  
- Produce transparent models that ecologists can inspect, critique, and modify  
- Use available monitoring data for validation (checking plausibility, not training)

**It doesn't:**

- Provide precise predictions of what *will* happen—long-term ecological forecasting is inherently uncertain  
- Automatically handle new interventions—if you want to test something not yet parameterized (e.g., caging seedlings to prevent herbivory), that requires model development first  
- Replace empirical models where sufficient data exist—different tools for different situations

### Our design philosophy

We favor transparency over more opaque approaches, which may have more predictive power but lack interpretability. Process-based models are built around ecological mechanisms that domain experts can examine—growth rates, survival probabilities, competitive effects. When a model behaves unexpectedly, users can trace behaviors back to ecological interactions. This matters for building trust with managers and scientists who need to understand what's driving projections before acting on them.

Crucially, we want vegetation modeling to be a collaborative process rather than something bifurcated between "field people" and "modeling people." The goal is to build models that vegetation ecologists and land managers can engage with directly— the model becomes a shared asset that represents collective understanding of how the system works.

---

## Resource Optimization

### Why we're building it

After characterizing a disturbance and building vegetation models, managers face a combinatorial explosion of choices: Where should we seed? Where should we plant juveniles? Should we remove invasive species first? How much labor can we afford to invest in each hectare? What if we have limited seed supply? What if seedlings need to be planted near roads so crews can water them?

Each combination of treatment × location × timing × intensity produces different projected outcomes. Even for a modest burn scar with a handful of treatment options, the number of permutations quickly exceeds what anyone can reason about intuitively.

### What it will do

Resource Optimization sits between manager intent and vegetation modeling. It takes constraints (seed availability, labor, budget, logistics like road access) and candidate management strategies, then drives josh to run the appropriate simulations—potentially thousands of replicates per scenario to characterize uncertainty. It then structures the comparison of outputs so managers can evaluate tradeoffs.

Resource Optimization's job is to trigger and catalog independent runs of \`Vegetation Modelling\`, under different management interventions, given the constraints that managers care about: seed, labor, and other resources. 

### What it will and won't do

**It will:**

- Translate management constraints into simulation specifications  
- Drive josh to run appropriate scenarios (many replicates, multiple strategies)  
- Structure side-by-side comparison of projected outcomes  
- Surface tradeoffs between cost, effort, and ecological outcomes

**It won't:**

- Tell managers what to do—decisions involve values, risk tolerance, and local knowledge that can't be automated  
- Test interventions that haven't been parameterized in the vegetation model—new interventions require model development first  
- Solve the "optimal" management problem—that requires agreement on criteria we can't assume

### Our design philosophy

We view resource optimization as a way to help managers *reason about* many possible futures, not to automate decision-making. The goal is to make tradeoffs explicit and quantifiable while leaving the ultimate choices—which involve values, risk tolerance, and local knowledge—with the people responsible for stewardship.

We're actively seeking input on how to approach these challenges well\!

---

## Design Principles

**Partner-driven development.** We build tools in close collaboration with land managers. This means prioritizing features that address real operational needs, even when those needs don't align with cutting-edge research agendas.

**Transparency over black boxes.** We favor approaches where domain experts can inspect, critique, and modify the underlying logic. For vegetation modeling, this means process-based models built around ecological mechanisms rather than opaque machine learning.

**Collaborative modeling.** We want vegetation models to be shared assets developed jointly by field ecologists, land managers, and quantitative scientists—not something built by one group and handed to another.

**Honesty about uncertainty.** Long-term ecological prediction is inherently uncertain. We aim to quantify and communicate that uncertainty rather than hiding it behind false precision.

**Open tools.** All components (including josh) are open-source. We want these approaches to be adopted, adapted, and improved by others facing similar challenges.  
