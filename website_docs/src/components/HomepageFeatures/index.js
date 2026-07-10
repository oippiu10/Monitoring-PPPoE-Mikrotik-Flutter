import clsx from 'clsx';
import Heading from '@theme/Heading';
import styles from './styles.module.css';

const FeatureList = [
  {
    title: 'Monitoring Real-time',
    Svg: require('@site/static/img/undraw_docusaurus_mountain.svg').default,
    description: (
      <>
        Pantau status PPPoE, resource CPU & Memory, hingga traffic jaringan
        pelanggan Mikrotik Anda secara langsung tanpa delay.
      </>
    ),
  },
  {
    title: 'Manajemen Billing Otomatis',
    Svg: require('@site/static/img/undraw_docusaurus_tree.svg').default,
    description: (
      <>
        Kelola tagihan pelanggan, riwayat pembayaran, dan sinkronisasi data 
        secara otomatis dengan database internal Anda.
      </>
    ),
  },
  {
    title: 'Super Cepat & Aman',
    Svg: require('@site/static/img/undraw_docusaurus_react.svg').default,
    description: (
      <>
        Ditenagai oleh Flutter untuk aplikasi mobile dan REST API Mikrotik
        yang sudah diperkuat dengan protokol keamanan tinggi.
      </>
    ),
  },
];

function Feature({Svg, title, description}) {
  return (
    <div className={clsx('col col--4')}>
      <div className="text--center">
        <Svg className={styles.featureSvg} role="img" />
      </div>
      <div className="text--center padding-horiz--md">
        <Heading as="h3">{title}</Heading>
        <p>{description}</p>
      </div>
    </div>
  );
}

export default function HomepageFeatures() {
  return (
    <section className={styles.features}>
      <div className="container">
        <div className="row">
          {FeatureList.map((props, idx) => (
            <Feature key={idx} {...props} />
          ))}
        </div>
      </div>
    </section>
  );
}
